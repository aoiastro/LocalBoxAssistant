import AVFoundation
import Foundation

@MainActor
final class TextToSpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var finishHandler: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    func speak(_ text: String, onFinish: (() -> Void)? = nil) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.1
        finishHandler = onFinish
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finishHandler = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let handler = finishHandler
        finishHandler = nil
        handler?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finishHandler = nil
    }
}
