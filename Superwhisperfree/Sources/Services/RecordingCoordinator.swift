import Cocoa

final class RecordingCoordinator {
    
    static let shared = RecordingCoordinator()
    
    private let audioRecorder = AudioRecorder()
    private let overlay = RecordingOverlay()
    private let transcriptionClient = TranscriptionClient.shared
    private let pasteService = PasteService.shared
    private let hotkeyManager = HotkeyManager.shared
    
    private var currentRecordingURL: URL?
    private var isRecording = false
    private var recordingStartTime: Date?
    
    private init() {
        setupHotkeyCallbacks()
        setupAudioLevelCallback()
    }
    
    func start() {
        print("RecordingCoordinator: start() called")
        transcriptionClient.start()
        hotkeyManager.start()
        print("RecordingCoordinator: started successfully")
    }
    
    func stop() {
        hotkeyManager.stop()
        cancelRecording()
    }
    
    func restartHotkey() {
        hotkeyManager.restart()
    }
    
    private func setupHotkeyCallbacks() {
        hotkeyManager.onHotkeyDown = { [weak self] in
            self?.handleHotkeyDown()
        }
        
        hotkeyManager.onHotkeyUp = { [weak self] in
            self?.handleHotkeyUp()
        }
    }
    
    private func setupAudioLevelCallback() {
        audioRecorder.onAudioLevel = { [weak self] level in
            self?.overlay.updateAudioLevel(level)
        }
    }
    
    private func handleHotkeyDown() {
        print("RecordingCoordinator: handleHotkeyDown() called, isRecording=\(isRecording)")
        guard !isRecording else { return }
        
        isRecording = true
        recordingStartTime = Date()
        postRecordingStateNotification(isRecording: true)
        
        DispatchQueue.main.async { [weak self] in
            print("RecordingCoordinator: Showing overlay and starting recording")
            self?.overlay.setState(.recording)
            self?.overlay.showNearCursor()
        }
        
        do {
            currentRecordingURL = try audioRecorder.startRecording()
            print("RecordingCoordinator: Recording started at \(currentRecordingURL?.path ?? "nil")")
        } catch {
            print("RecordingCoordinator: Failed to start recording - \(error)")
            recordingStartTime = nil
            handleError("Failed to start recording")
        }
    }
    
    private func handleHotkeyUp() {
        guard isRecording else { return }
        
        isRecording = false
        let recordingDuration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartTime = nil
        postRecordingStateNotification(isRecording: false)
        
        guard let recordingURL = audioRecorder.stopRecording() else {
            handleError("No recording to process")
            return
        }
        
        currentRecordingURL = recordingURL
        
        DispatchQueue.main.async { [weak self] in
            self?.overlay.setState(.transcribing)
        }
        
        transcriptionClient.transcribe(audioPath: recordingURL.path) { [weak self] result in
            switch result {
            case .success(let text):
                self?.handleTranscriptionSuccess(text, duration: recordingDuration)
            case .failure(let error):
                self?.handleError(error.localizedDescription)
            }
        }
    }
    
    private func handleTranscriptionSuccess(_ text: String, duration: TimeInterval) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            handleError("No speech detected")
            return
        }
        
        overlay.setState(.success)
        
        AnalyticsManager.shared.addTranscription(text: trimmedText, durationSeconds: duration)
        print("RecordingCoordinator: Added transcription - \(trimmedText.prefix(50))... duration: \(duration)s")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.pasteService.pasteText(trimmedText)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.overlay.hide { [weak self] in
                    self?.cleanup()
                }
            }
        }
    }
    
    private func handleError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.overlay.setState(.error(message))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.overlay.hide { [weak self] in
                    self?.cleanup()
                }
            }
        }
    }
    
    private func cancelRecording() {
        if isRecording {
            _ = audioRecorder.stopRecording()
            isRecording = false
        }
        
        overlay.hide()
        cleanup()
    }
    
    private func cleanup() {
        audioRecorder.cleanup()
        currentRecordingURL = nil
        recordingStartTime = nil
    }
    
    private func postRecordingStateNotification(isRecording: Bool) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .recordingStateDidChange,
                object: nil,
                userInfo: ["isRecording": isRecording]
            )
        }
    }
}
