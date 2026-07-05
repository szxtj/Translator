import ScreenCaptureKit
import AVFoundation

class AudioCaptureManager: NSObject, SCStreamOutput, @unchecked Sendable {
    private var stream: SCStream?
    private var recognizer: SpeechRecognizerManager?
    private var hasReceivedAudio = false

    func startCapture(recognizer: SpeechRecognizerManager) async throws {
        self.recognizer = recognizer
        self.hasReceivedAudio = false

        debugLog("[AudioCaptureManager] Querying shareable content...")
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = shareableContent.displays.first else {
            throw NSError(domain: "AudioCaptureManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display found."])
        }

        debugLog("[AudioCaptureManager] Setting up content filter for display...")
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.width = 16
        config.height = 16

        debugLog("[AudioCaptureManager] Creating SCStream...")
        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.translator.audio-capture"))
        
        debugLog("[AudioCaptureManager] Starting screen capture stream...")
        try await stream?.startCapture()
        debugLog("[AudioCaptureManager] Stream started successfully.")
    }

    func stopCapture() async throws {
        debugLog("[AudioCaptureManager] Stopping stream...")
        try await stream?.stopCapture()
        stream = nil
        recognizer = nil
        hasReceivedAudio = false
        debugLog("[AudioCaptureManager] Stream stopped.")
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        if !hasReceivedAudio {
            hasReceivedAudio = true
            debugLog("[AudioCaptureManager] First audio buffer frame received successfully!")
        }
        recognizer?.appendAudioBuffer(sampleBuffer)
    }
}
