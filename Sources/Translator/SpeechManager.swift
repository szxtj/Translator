import AVFoundation
import NaturalLanguage

@MainActor
final class SpeechManager: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String) {
        stop()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("[SpeechManager] Text is empty, skipping speech.")
            return
        }

        let utterance = AVSpeechUtterance(string: trimmed)

        // Detect language using local NaturalLanguage framework
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        let language = recognizer.dominantLanguage?.rawValue ?? "en"
        print("[SpeechManager] Detected language raw value: \(language)")

        // Find available voice matching language code (e.g. prefix match like "zh" or "en")
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let voiceLang = language.lowercased().starts(with: "zh") ? "zh" : "en"
        let matchedVoice = voices.first { $0.language.lowercased().starts(with: voiceLang) }

        if let voice = matchedVoice {
            print("[SpeechManager] Selected voice: \(voice.name) (\(voice.language))")
            utterance.voice = voice
        } else {
            let fallbackLang = voiceLang == "zh" ? "zh-CN" : "en-US"
            print("[SpeechManager] No direct voice prefix match, falling back to: \(fallbackLang)")
            utterance.voice = AVSpeechSynthesisVoice(language: fallbackLang)
        }

        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0

        print("[SpeechManager] Synthesizer speak() called.")
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        print("[SpeechManager] stop() called. Is speaking: \(synthesizer.isSpeaking)")
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("[SpeechManager] didStart utterance: \(utterance.speechString.prefix(20))...")
        Task { @MainActor in
            self.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("[SpeechManager] didFinish utterance")
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("[SpeechManager] didCancel utterance")
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
