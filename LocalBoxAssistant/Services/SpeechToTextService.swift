import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechToTextService {
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isStarting = false

    var isListening: Bool {
        audioEngine.isRunning
    }

    func requestPermissions() async throws {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speech == .authorized else {
            throw LocalLLMError.sttFailed("Speech recognition permission denied")
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else {
            throw LocalLLMError.sttFailed("Microphone permission denied")
        }
    }

    func startListening(onPartial: @escaping @Sendable (String) -> Void) throws {
        if isStarting || audioEngine.isRunning {
            return
        }
        isStarting = true
        defer { isStarting = false }

        stopListening()

        guard let recognizer, recognizer.isAvailable else {
            throw LocalLLMError.sttFailed("Speech recognizer unavailable")
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        recognitionRequest = request
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            throw LocalLLMError.sttFailed("Invalid input audio format")
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                onPartial(result.bestTranscription.formattedString)
            }

            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    self?.restartIfNeeded(onPartial: onPartial)
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func restartIfNeeded(onPartial: @escaping @Sendable (String) -> Void) {
        guard audioEngine.isRunning else { return }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        do {
            try startListening(onPartial: onPartial)
        } catch {
            stopListening()
        }
    }
}
