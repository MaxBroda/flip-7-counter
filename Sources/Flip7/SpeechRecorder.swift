import AVFoundation
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

    func prepare() async {
        guard await Self.requestMicrophone() else { return problem = .microphoneDenied }
        do {
            _ = try await Self.makeTranscriber()
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
        guard await Self.requestMicrophone() else { return problem = .microphoneDenied }
        do {
            let session = try await Session(transcriber: Self.makeTranscriber(), hints: hints) { [weak self] text in
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

    func stop() async -> String {
        guard isListening, let session else {
            stopRequested = isStarting
            return transcript
        }
        try? await Task.sleep(for: .milliseconds(350))
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        self.session = nil
        transcript = await session.finish()
        isListening = false
        return transcript
    }

    private static func makeTranscriber() async throws -> DictationTranscriber {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de-DE")) else {
            throw SpeechProblem.languageUnavailable
        }
        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
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

    init(transcriber: DictationTranscriber, hints: [String], onUpdate: @escaping @MainActor (String) -> Void) async throws {
        analyzer = SpeechAnalyzer(modules: [transcriber], options: .init(priority: .userInitiated, modelRetention: .processLifetime))
        converter = try await AnalyzerInputConverter.converter(compatibleWith: [transcriber])
        let (stream, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.input = input
        collector = Task {
            var finalized: [String] = []
            var volatile = ""
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters).trimmingCharacters(in: .whitespaces)
                    if result.isFinal {
                        finalized.append(text)
                        volatile = ""
                    } else {
                        volatile = text
                    }
                    let combined = (finalized + [volatile]).filter { !$0.isEmpty }.joined(separator: " ")
                    await onUpdate(combined)
                }
            } catch {}
            return (finalized + [volatile]).filter { !$0.isEmpty }.joined(separator: " ")
        }
        let context = AnalysisContext()
        context.contextualStrings[.general] = hints
        try await analyzer.setContext(context)
        try await analyzer.start(inputSequence: stream)
    }

    var tap: AVAudioNodeTapBlock {
        { [self] buffer, _ in
            if micFormat == nil {
                micFormat = buffer.format
                feed(silence(seconds: 0.5, format: buffer.format))
            }
            feed(buffer)
        }
    }

    // The transcriber drops speech at the very start of a stream and holds back the last word
    // until more audio follows, so every utterance is padded with silence on both ends.
    func finish() async -> String {
        if let micFormat { feed(silence(seconds: 0.8, format: micFormat)) }
        (try? converter.flush())?.forEach { input.yield($0) }
        input.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        return await collector.value
    }

    private func feed(_ buffer: AVAudioPCMBuffer?) {
        guard let buffer else { return }
        (try? converter.convert(buffer, at: nil))?.forEach { input.yield($0) }
    }

    private func silence(seconds: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate * seconds)),
              let channels = buffer.floatChannelData
        else { return nil }
        buffer.frameLength = buffer.frameCapacity
        for channel in 0..<Int(format.channelCount) {
            channels[channel].update(repeating: 0, count: Int(buffer.frameLength))
        }
        return buffer
    }

    func cancel() async {
        input.finish()
        await analyzer.cancelAndFinishNow()
        collector.cancel()
    }
}
