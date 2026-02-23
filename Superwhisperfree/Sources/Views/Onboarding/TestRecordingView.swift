import Cocoa
import AVFoundation

final class TestRecordingView: NSView {
    
    var onComplete: (() -> Void)?
    
    private let statusLabel = NSTextField(labelWithString: "Hold your hotkey to try recording")
    private var transcriptionTextField: NSTextField!
    private var waveformView: WaveformView!
    private var continueButton: NSButton!
    private var skipButton: NSButton!
    private let transcriptionClient = TranscriptionClient.shared
    
    private var audioRecorder: AudioRecorder?
    private var isRecording = false
    private var recordingCompleted = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    deinit {
        cleanup()
    }
    
    private func setup() {
        wantsLayer = true
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = DesignTokens.Spacing.md
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Try It Out!")
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = NSColor.swText
        titleLabel.alignment = .center
        
        statusLabel.font = DesignTokens.Typography.body(size: 14)
        statusLabel.textColor = NSColor.swTextSecondary
        statusLabel.alignment = .center
        
        waveformView = WaveformView()
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        
        transcriptionTextField = NSTextField()
        transcriptionTextField.translatesAutoresizingMaskIntoConstraints = false
        transcriptionTextField.font = DesignTokens.Typography.body(size: 14)
        transcriptionTextField.textColor = NSColor.swText
        transcriptionTextField.backgroundColor = NSColor.swSurface
        transcriptionTextField.isBordered = true
        transcriptionTextField.isEditable = false
        transcriptionTextField.isSelectable = true
        transcriptionTextField.alignment = .center
        transcriptionTextField.placeholderString = "Your transcription will appear here..."
        transcriptionTextField.lineBreakMode = .byWordWrapping
        transcriptionTextField.cell?.wraps = true
        transcriptionTextField.cell?.isScrollable = false
        
        let buttonsStack = NSStackView()
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = DesignTokens.Spacing.md
        
        skipButton = createButton(title: "Skip") { [weak self] in
            self?.skip()
        }
        
        continueButton = createButton(title: "Continue") { [weak self] in
            self?.onComplete?()
        }
        continueButton.isHidden = true
        
        buttonsStack.addArrangedSubview(skipButton)
        buttonsStack.addArrangedSubview(continueButton)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(waveformView)
        stackView.addArrangedSubview(transcriptionTextField)
        stackView.addArrangedSubview(buttonsStack)
        
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: statusLabel)
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: waveformView)
        stackView.setCustomSpacing(DesignTokens.Spacing.xl, after: transcriptionTextField)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            waveformView.widthAnchor.constraint(equalToConstant: 120),
            waveformView.heightAnchor.constraint(equalToConstant: 40),
            transcriptionTextField.widthAnchor.constraint(equalToConstant: 350),
            transcriptionTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            skipButton.widthAnchor.constraint(equalToConstant: 80),
            skipButton.heightAnchor.constraint(equalToConstant: 36),
            continueButton.widthAnchor.constraint(equalToConstant: 100),
            continueButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        setupRecording()
    }
    
    private func setupRecording() {
        transcriptionClient.start()
        
        audioRecorder = AudioRecorder()
        audioRecorder?.onAudioLevel = { [weak self] level in
            self?.waveformView.updateLevel(level)
        }
        
        setupKeyMonitor()
    }
    
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    
    private func setupKeyMonitor() {
        let settings = SettingsManager.shared.settings
        
        guard !settings.hotkey.modifiers.isEmpty || !settings.hotkey.key.isEmpty else {
            statusLabel.stringValue = "Please configure a hotkey first"
            statusLabel.textColor = NSColor.swError
            return
        }
        
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let settings = SettingsManager.shared.settings
        
        let modifiersActive = checkModifiersActive(event: event, config: settings.hotkey)
        
        if modifiersActive && !isRecording {
            startTestRecording()
        } else if !modifiersActive && isRecording {
            stopTestRecording()
        }
    }
    
    private func checkModifiersActive(event: NSEvent, config: HotkeyConfig) -> Bool {
        let flags = event.modifierFlags
        
        for modifier in config.modifiers {
            switch modifier.lowercased() {
            case "rightalt", "rightoption":
                if flags.contains(.option) && event.keyCode == 61 {
                    return true
                }
            case "leftalt", "leftoption":
                if flags.contains(.option) && event.keyCode == 58 {
                    return true
                }
            case "alt", "option":
                if flags.contains(.option) {
                    return true
                }
            case "rightcmd", "rightcommand":
                if flags.contains(.command) && event.keyCode == 54 {
                    return true
                }
            case "leftcmd", "leftcommand":
                if flags.contains(.command) && event.keyCode == 55 {
                    return true
                }
            case "control", "ctrl":
                if flags.contains(.control) {
                    return true
                }
            case "shift":
                if flags.contains(.shift) {
                    return true
                }
            case "command", "cmd":
                if flags.contains(.command) {
                    return true
                }
            case "fn", "function":
                if flags.contains(.function) {
                    return true
                }
            default:
                break
            }
        }
        
        return false
    }
    
    private func startTestRecording() {
        guard !isRecording else { return }
        isRecording = true
        
        statusLabel.stringValue = "Recording..."
        statusLabel.textColor = NSColor.swAccent
        waveformView.startAnimating()
        
        do {
            _ = try audioRecorder?.startRecording()
        } catch {
            statusLabel.stringValue = "Failed to start recording: \(error.localizedDescription)"
            statusLabel.textColor = NSColor.swError
            isRecording = false
        }
    }
    
    private func stopTestRecording() {
        guard isRecording else { return }
        isRecording = false
        
        waveformView.stopAnimating()
        
        if let url = audioRecorder?.stopRecording() {
            statusLabel.stringValue = "Transcribing..."
            statusLabel.textColor = NSColor.swTextSecondary
            
            performTranscription(audioURL: url)
        }
    }
    
    private func performTranscription(audioURL: URL) {
        transcriptionClient.transcribe(audioPath: audioURL.path) { [weak self] result in
            guard let self = self else { return }
            
            defer {
                try? FileManager.default.removeItem(at: audioURL)
            }
            
            switch result {
            case .success(let text):
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedText.isEmpty {
                    self.showTranscriptionResult("(No speech detected - try again)", isError: true)
                } else {
                    self.showTranscriptionResult(trimmedText, isError: false)
                }
            case .failure(let error):
                self.showTranscriptionResult("Error: \(error.localizedDescription)", isError: true)
            }
        }
    }
    
    private func showTranscriptionResult(_ text: String, isError: Bool) {
        recordingCompleted = !isError
        
        if isError {
            statusLabel.stringValue = "Try again"
            statusLabel.textColor = NSColor.swError
            transcriptionTextField.textColor = NSColor.swError
        } else {
            statusLabel.stringValue = "Success!"
            statusLabel.textColor = NSColor.swSuccess
            transcriptionTextField.textColor = NSColor.swText
            continueButton.isHidden = false
            skipButton.isHidden = true
        }
        
        transcriptionTextField.stringValue = text
    }
    
    private func skip() {
        cleanup()
        onComplete?()
    }
    
    private func cleanup() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }
        
        audioRecorder?.cleanup()
        audioRecorder = nil
    }
    
    private func createButton(title: String, action: @escaping () -> Void) -> NSButton {
        let button = TestActionButton(title: title, action: action)
        return button
    }
}

private class TestActionButton: NSButton {
    
    private var actionHandler: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { updateAppearance() }
    }
    
    convenience init(title: String, action: @escaping () -> Void) {
        self.init(frame: .zero)
        self.title = title
        self.actionHandler = action
        setup()
    }
    
    private func setup() {
        isBordered = false
        bezelStyle = .inline
        font = DesignTokens.Typography.body(size: 13)
        target = self
        self.action = #selector(buttonClicked)
        
        wantsLayer = true
        layer?.cornerRadius = DesignTokens.CornerRadius.medium
        layer?.borderWidth = 1
        
        updateAppearance()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    private func updateAppearance() {
        layer?.backgroundColor = isHovered ? NSColor.swText.cgColor : NSColor.clear.cgColor
        layer?.borderColor = NSColor.swText.cgColor
        contentTintColor = isHovered ? NSColor.swBackground : NSColor.swText
    }
    
    @objc private func buttonClicked() {
        actionHandler?()
    }
}
