import AVFoundation
import Observation
import Speech

enum SpeechProblem: Error, Equatable {
    case microphoneDenied
    case recognitionDenied
    case recognizerUnavailable
    case audio(String)

    var message: String {
        switch self {
        case .microphoneDenied: "Kein Mikrofonzugriff. Bitte in Systemeinstellungen › Datenschutz › Mikrofon erlauben."
        case .recognitionDenied: "Keine Spracherkennung erlaubt. Bitte in Systemeinstellungen › Datenschutz › Spracherkennung erlauben."
        case .recognizerUnavailable: "Die deutsche Spracherkennung ist gerade nicht verfügbar."
        case .audio(let detail): "Mikrofon konnte nicht starten: \(detail)"
        }
    }
}

@MainActor
@Observable
final class SpeechRecorder {
    private(set) var isListening = false
    private(set) var transcript = ""
    private(set) var problem: SpeechProblem?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var completion: CheckedContinuation<String, Never>?
    private var isStarting = false
    private var stopRequested = false

    func start(hints: [String]) async {
        guard !isListening, !isStarting else { return }
        transcript = ""
        problem = nil
        isStarting = true
        stopRequested = false
        defer { isStarting = false }
        guard await Self.requestMicrophone() else { return fail(.microphoneDenied) }
        guard await Self.requestRecognition() else { return fail(.recognitionDenied) }
        guard !stopRequested else { return }
        guard let recognizer, recognizer.isAvailable else { return fail(.recognizerUnavailable) }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = hints
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0), block: Self.tap(into: request))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            return fail(.audio(error.localizedDescription))
        }
        self.request = request
        task = recognizer.recognitionTask(with: request, resultHandler: Self.handler(for: self))
        isListening = true
    }

    func stop() async -> String {
        guard isListening else {
            stopRequested = isStarting
            return transcript
        }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        return await withCheckedContinuation { continuation in
            completion = continuation
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                finish()
            }
        }
    }

    private func receive(text: String?, isFinal: Bool) {
        if let text { transcript = text }
        if isFinal { finish() }
    }

    private func finish() {
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        completion?.resume(returning: transcript)
        completion = nil
    }

    private func fail(_ problem: SpeechProblem) {
        self.problem = problem
        isListening = false
    }

    private nonisolated static func tap(into request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    private nonisolated static func handler(for recorder: SpeechRecorder) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak recorder] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in recorder?.receive(text: text, isFinal: isFinal) }
        }
    }

    private nonisolated static func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        default: false
        }
    }

    private nonisolated static func requestRecognition() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }
}
