import AVFoundation
import Foundation

final class AudioRecorder {
    
    private var audioRecorder: AVAudioRecorder?
    private var meteringTimer: Timer?
    private var currentRecordingURL: URL?
    
    var onAudioLevel: ((Float) -> Void)?
    
    private var appSupportDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("Superwhisperfree", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }
    
    func startRecording() throws -> URL {
        let url = appSupportDirectory.appendingPathComponent("recording_\(UUID().uuidString).wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        
        guard audioRecorder?.record() == true else {
            throw RecordingError.failedToStart
        }
        
        currentRecordingURL = url
        startMeteringTimer()
        
        return url
    }
    
    func stopRecording() -> URL? {
        stopMeteringTimer()
        audioRecorder?.stop()
        let url = currentRecordingURL
        audioRecorder = nil
        return url
    }
    
    func cleanup() {
        stopMeteringTimer()
        audioRecorder?.stop()
        audioRecorder = nil
        
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
            currentRecordingURL = nil
        }
    }
    
    private func startMeteringTimer() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateMetering()
        }
    }
    
    private func stopMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }
    
    private func updateMetering() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert dB to normalized 0-1 range
        // Average power ranges from -160 (silence) to 0 (max)
        let minDb: Float = -60.0
        let maxDb: Float = 0.0
        let clampedPower = max(minDb, min(maxDb, averagePower))
        let normalizedLevel = (clampedPower - minDb) / (maxDb - minDb)
        
        DispatchQueue.main.async { [weak self] in
            self?.onAudioLevel?(normalizedLevel)
        }
    }
}

enum RecordingError: LocalizedError {
    case failedToStart
    case noMicrophoneAccess
    
    var errorDescription: String? {
        switch self {
        case .failedToStart:
            return "Failed to start recording"
        case .noMicrophoneAccess:
            return "Microphone access denied"
        }
    }
}
