import AVFoundation
import Flip7Core
import Observation
import Speech

enum SpeechProblem: Error, Equatable {
    case microphoneDenied
    case languageUnavailable
    case failed(String)

    var message: String {
        switch self {
        case .microphoneDenied: "Kein Mikrofonzugriff. Bitte in Systemeinstellungen › Datenschutz › Mikrofon für Flip 7 erlauben."
        case .languageUnavailable: "Deutsche Spracherkennung ist auf diesem Mac nicht verfügbar."
        case .failed(let detail): "Aufnahme fehlgeschlagen: \(detail)"
        }
    }
}

struct Utterance {
    let live: String
    let segmented: String

    var text: String { segmented.isEmpty ? live : segmented }
}

@MainActor
@Observable
final class SpeechRecorder {
    private(set) var isListening = false
    private(set) var transcript = ""
    private(set) var problem: SpeechProblem?

    private let engine = AVAudioEngine()
    private var session: Session?
    private var isStarting = false
    private var stopRequested = false
    private var hints: [String] = []

    func prepare() async {
        guard await Self.requestMicrophone() else { return problem = .microphoneDenied }
        do {
            _ = try await Self.makeTranscriber(preset: .progressiveShortDictation)
            _ = try await Self.makeTranscriber(preset: .shortDictation)
            _ = engine.inputNode
            engine.prepare()
        } catch let error as SpeechProblem {
            problem = error
        } catch {
            problem = .failed(error.localizedDescription)
        }
    }

    func start(hints: [String]) async {
        guard !isListening, !isStarting else { return }
        isStarting = true
        stopRequested = false
        defer { isStarting = false }
        transcript = ""
        problem = nil
        self.hints = hints
        guard await Self.requestMicrophone() else { return problem = .microphoneDenied }
        do {
            let session = try await Session(transcriber: Self.makeTranscriber(preset: .progressiveShortDictation), hints: hints) { [weak self] text in
                self?.transcript = text
            }
            guard !stopRequested else { return await session.cancel() }
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 2048, format: input.outputFormat(forBus: 0), block: session.tap)
            engine.prepare()
            try engine.start()
            self.session = session
            isListening = true
        } catch let error as SpeechProblem {
            problem = error
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            problem = .failed(error.localizedDescription)
        }
    }

    func stop() async -> Utterance {
        guard isListening, let session else {
            stopRequested = isStarting
            return Utterance(live: transcript, segmented: "")
        }
        try? await Task.sleep(for: .milliseconds(350))
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        self.session = nil
        let live = await session.finish()
        transcript = live
        let utterance = Utterance(live: live, segmented: await Self.transcribeSegments(of: session.recording, hints: hints))
        transcript = utterance.text
        isListening = false
        return utterance
    }

    // Live dictation drops speech that follows a pause when the speaker changes (one person names,
    // another answers with the score), so each pause-separated piece is recognized on its own.
    private nonisolated static func transcribeSegments(of recording: Recording?, hints: [String]) async -> String {
        guard let recording else { return "" }
        let pieces = PauseSegmenter(sampleRate: recording.format.sampleRate).segments(in: recording.samples)
        let texts = await withTaskGroup(of: (Int, String).self) { group in
            for (index, range) in pieces.enumerated() {
                group.addTask {
                    let text = try? await transcribe(recording.slice(range), format: recording.format, hints: hints)
                    return (index, text ?? "")
                }
            }
            return await group.reduce(into: [:]) { $0[$1.0] = $1.1 }
        }
        return pieces.indices.compactMap { texts[$0] }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private nonisolated static func transcribe(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat, hints: [String]) async throws -> String {
        let transcriber = try await makeTranscriber(preset: .shortDictation)
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: .init(priority: .userInitiated, modelRetention: .processLifetime))
        let context = AnalysisContext()
        context.contextualStrings[.general] = hints
        try await analyzer.setContext(context)
        let converter = try await AnalyzerInputConverter.converter(compatibleWith: [transcriber])
        let (stream, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let collector = Task { await transcriber.transcript() }
        try await analyzer.start(inputSequence: stream)
        for piece in [Recording.silence(seconds: 0.5, format: format), buffer, Recording.silence(seconds: 0.8, format: format)] {
            try converter.convert(piece, at: nil).forEach { input.yield($0) }
        }
        try converter.flush().forEach { input.yield($0) }
        input.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        return await collector.value
    }

    private nonisolated static func makeTranscriber(preset: DictationTranscriber.Preset) async throws -> DictationTranscriber {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de-DE")) else {
            throw SpeechProblem.languageUnavailable
        }
        let transcriber = DictationTranscriber(locale: locale, preset: preset)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        return transcriber
    }

    private nonisolated static func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        default: false
        }
    }
}

private final class Session: @unchecked Sendable {
    private let analyzer: SpeechAnalyzer
    private let converter: AnalyzerInputConverter
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let collector: Task<String, Never>
    private var micFormat: AVAudioFormat?
    private var samples: [Float] = []

    var recording: Recording? {
        guard let micFormat, !samples.isEmpty else { return nil }
        return Recording(samples: samples, sampleRate: micFormat.sampleRate)
    }

    init(transcriber: DictationTranscriber, hints: [String], onUpdate: @escaping @MainActor (String) -> Void) async throws {
        analyzer = SpeechAnalyzer(modules: [transcriber], options: .init(priority: .userInitiated, modelRetention: .processLifetime))
        converter = try await AnalyzerInputConverter.converter(compatibleWith: [transcriber])
        let (stream, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.input = input
        collector = Task { await transcriber.transcript(onUpdate: onUpdate) }
        let context = AnalysisContext()
        context.contextualStrings[.general] = hints
        try await analyzer.setContext(context)
        try await analyzer.start(inputSequence: stream)
    }

    var tap: AVAudioNodeTapBlock {
        { [self] buffer, _ in
            if micFormat == nil {
                micFormat = buffer.format
                feed(Recording.silence(seconds: 0.5, format: buffer.format))
            }
            if let channel = buffer.floatChannelData?[0] {
                samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            }
            feed(buffer)
        }
    }

    // The transcriber drops speech at the very start of a stream and holds back the last word
    // until more audio follows, so every utterance is padded with silence on both ends.
    func finish() async -> String {
        if let micFormat { feed(Recording.silence(seconds: 0.8, format: micFormat)) }
        (try? converter.flush())?.forEach { input.yield($0) }
        input.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        return await collector.value
    }

    private func feed(_ buffer: AVAudioPCMBuffer?) {
        guard let buffer else { return }
        (try? converter.convert(buffer, at: nil))?.forEach { input.yield($0) }
    }

    func cancel() async {
        input.finish()
        await analyzer.cancelAndFinishNow()
        collector.cancel()
    }
}

private struct Recording: Sendable {
    let samples: [Float]
    let format: AVAudioFormat

    init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    func slice(_ range: Range<Int>) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(range.count))!
        buffer.frameLength = buffer.frameCapacity
        let piece = samples[range]
        let peak = piece.reduce(0) { max($0, abs($1)) }
        let gain = peak > 0 ? min(0.5 / peak, 40) : 1
        let output = buffer.floatChannelData![0]
        for (offset, sample) in piece.enumerated() { output[offset] = sample * gain }
        return buffer
    }

    static func silence(seconds: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate * seconds))!
        buffer.frameLength = buffer.frameCapacity
        for channel in 0..<Int(format.channelCount) {
            buffer.floatChannelData![channel].update(repeating: 0, count: Int(buffer.frameLength))
        }
        return buffer
    }
}

private extension DictationTranscriber {
    func transcript(onUpdate: @escaping @MainActor (String) -> Void = { _ in }) async -> String {
        var finalized: [String] = []
        var volatile = ""
        var combined: String { (finalized + [volatile]).filter { !$0.isEmpty }.joined(separator: " ") }
        do {
            for try await result in results {
                let text = String(result.text.characters).trimmingCharacters(in: .whitespaces)
                if result.isFinal {
                    finalized.append(text)
                    volatile = ""
                } else {
                    volatile = text
                }
                await onUpdate(combined)
            }
        } catch {}
        return combined
    }
}
