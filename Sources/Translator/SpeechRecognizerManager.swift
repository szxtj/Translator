import Speech
import AVFoundation

class SpeechRecognizerManager: NSObject, @unchecked Sendable {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var textHandler: ((String) -> Void)?

    // Target format: 16000 Hz, 1 channel (mono) PCM
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    private var audioConverter: AVAudioConverter?

    func startRecognition(handler: @escaping (String) -> Void) throws {
        stopRecognition()
        self.textHandler = handler

        debugLog("[SpeechRecognizerManager] Checking speech recognizer availability...")
        guard speechRecognizer.isAvailable else {
            debugLog("[SpeechRecognizerManager] Speech recognizer is NOT available!")
            throw NSError(domain: "SpeechRecognizerManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available on this system."])
        }

        debugLog("[SpeechRecognizerManager] Initializing Speech recognition request...")
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        if speechRecognizer.supportsOnDeviceRecognition {
            debugLog("[SpeechRecognizerManager] On-device recognition supported by hardware.")
        }

        var task: SFSpeechRecognitionTask?
        task = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            // Critical Identity Check: ignore callbacks from cancelled/replaced legacy tasks
            guard self.recognitionTask === task else {
                debugLog("[SpeechRecognizerManager] Ignored obsolete callback from previous task.")
                return
            }

            if let result = result {
                let text = result.bestTranscription.formattedString
                debugLog("[SpeechRecognizerManager] Transcribed segment: \(text)")
                DispatchQueue.main.async {
                    self.textHandler?(text)
                }
            }
            if let error = error {
                debugLog("[SpeechRecognizerManager] Speech Task Error: \(error.localizedDescription)")
            }
        }
        self.recognitionTask = task
        debugLog("[SpeechRecognizerManager] Speech recognition task started.")
    }

    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let pcmBuffer = convertAndResample(sampleBuffer: sampleBuffer) {
            recognitionRequest?.append(pcmBuffer)
        }
    }

    func stopRecognition() {
        debugLog("[SpeechRecognizerManager] Stopping speech recognition...")
        self.textHandler = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioConverter = nil
    }

    private func convertAndResample(sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let sourceBuffer = convertToPCMBuffer(sampleBuffer: sampleBuffer) else { return nil }

        if audioConverter == nil || audioConverter?.inputFormat != sourceBuffer.format {
            debugLog("[SpeechRecognizerManager] Configuring resampler from \(sourceBuffer.format.sampleRate)Hz \(sourceBuffer.format.channelCount)Ch to 16000Hz 1Ch...")
            audioConverter = AVAudioConverter(from: sourceBuffer.format, to: targetFormat)
        }

        guard let converter = audioConverter else { return nil }

        let ratio = targetFormat.sampleRate / sourceBuffer.format.sampleRate
        let targetCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio) + 16

        guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetCapacity) else {
            return nil
        }

        var error: NSError?
        var isFirstCall = true
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            if isFirstCall {
                isFirstCall = false
                outStatus.pointee = .haveData
                return sourceBuffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        let status = converter.convert(to: targetBuffer, error: &error, withInputFrom: inputBlock)
        if status == .error || error != nil {
            debugLog("[SpeechRecognizerManager] Resampler error: \(error?.localizedDescription ?? "unknown")")
            return nil
        }

        return targetBuffer
    }

    private func convertToPCMBuffer(sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        return try? sampleBuffer.withAudioBufferList { audioBufferList, blockBuffer in
            guard let description = sampleBuffer.formatDescription?.audioStreamBasicDescription,
                  let format = AVAudioFormat(standardFormatWithSampleRate: description.mSampleRate, 
                                             channels: description.mChannelsPerFrame) else {
                return nil
            }
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, 
                                                   bufferListNoCopy: audioBufferList.unsafePointer) else {
                return nil
            }
            return pcmBuffer
        }
    }
}
