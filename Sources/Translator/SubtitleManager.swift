import Foundation
import Speech

struct SentencePair: Identifiable, Equatable {
    let id = UUID()
    let english: String
    let chinese: String
}

@MainActor
@available(macOS 26.4, *)
final class SubtitleManager: ObservableObject {
    @Published var englishText = ""
    @Published var translatedText: String?
    @Published var isListening = false
    @Published var finalizedPairs: [SentencePair] = []
    @Published var isHovered = false

    private let audioCapture = AudioCaptureManager()
    private let speechRecognizer = SpeechRecognizerManager()
    private var subtitleController: SubtitlePanelController?
    private var silenceTimer: Timer?

    init() {
        self.subtitleController = SubtitlePanelController(manager: self)
    }

    func toggle() {
        if isListening {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isListening else { return }

        let logPath = "/Users/justinxie/Projects/Translator/subtitle_debug.log"
        try? FileManager.default.removeItem(atPath: logPath)

        debugLog("[SubtitleManager] Requesting speech recognition permissions...")
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            Task { @MainActor in
                debugLog("[SubtitleManager] Speech recognition authorization status: \(status)")
                switch status {
                case .authorized:
                    self.startStreams()
                case .denied:
                    debugLog("[SubtitleManager] Permission Denied by user.")
                case .restricted:
                    debugLog("[SubtitleManager] Permission Restricted.")
                case .notDetermined:
                    debugLog("[SubtitleManager] Permission Undetermined.")
                @unknown default:
                    debugLog("[SubtitleManager] Unknown permission status.")
                }
            }
        }
    }

    private func startStreams() {
        debugLog("[SubtitleManager] Starting capture and transcription streams...")
        isListening = true
        englishText = ""
        translatedText = nil
        finalizedPairs = []
        isHovered = false
        subtitleController?.show()

        Task { [self] in
            do {
                try speechRecognizer.startRecognition { [weak self] text in
                    guard let self = self else { return }
                    self.processSpeechUpdate(text)
                }

                try await audioCapture.startCapture(recognizer: speechRecognizer)
            } catch {
                debugLog("[SubtitleManager] Error during stream startup: \(error.localizedDescription)")
                self.stop()
            }
        }
    }

    private func processSpeechUpdate(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Expand the window to the large/saved dimensions when active speech is detected
        subtitleController?.expandWindow()

        // Check if the current transcription segment ends with standard sentence punctuation
        let isFinalized = trimmed.last.map { ".?!".contains($0) } ?? false

        if isFinalized {
            self.englishText = trimmed
            self.finalizeSentence()
        } else {
            self.englishText = trimmed
            self.resetSilenceTimer()
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.finalizeSentence()
            }
        }
    }

    private func finalizeSentence() {
        guard isListening else { return }
        silenceTimer?.invalidate()

        let cleanEng = englishText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanChi = (translatedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanEng.isEmpty {
            debugLog("[SubtitleManager] Finalizing sentence: \(cleanEng) -> \(cleanChi)")
            let pair = SentencePair(english: cleanEng, chinese: cleanChi)
            finalizedPairs.append(pair)
            if finalizedPairs.count > 2 {
                finalizedPairs.removeFirst()
            }
        }

        // Reset active text buffers
        englishText = ""
        translatedText = nil

        // Restart recognition task to begin a clean slate for the next sentence
        do {
            try speechRecognizer.startRecognition { [weak self] text in
                guard let self = self else { return }
                self.processSpeechUpdate(text)
            }
        } catch {
            debugLog("[SubtitleManager] Error resetting recognition buffer: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard isListening else { return }
        debugLog("[SubtitleManager] Stopping subtitle stream and hiding overlay...")
        isListening = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        subtitleController?.hide()
        finalizedPairs = []
        isHovered = false

        Task {
            try? await audioCapture.stopCapture()
            speechRecognizer.stopRecognition()
        }
    }
}
