import Cocoa
import AVFoundation

final class TestRecordingView: NSView {
    
    var onComplete: (() -> Void)?
    
    private let statusLabel = NSTextField(labelWithString: "Hold your hotkey to try recording")
    private let resultLabel = NSTextField(wrappingLabelWithString: "")
    private var waveformView: WaveformView!
    private var continueButton: NSButton!
    private var skipButton: NSButton!
    
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
        
        resultLabel.font = DesignTokens.Typography.body(size: 14)
        resultLabel.textColor = NSColor.swText
        resultLabel.alignment = .center
        resultLabel.isHidden = true
        resultLabel.maximumNumberOfLines = 3
        
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
        stackView.addArrangedSubview(resultLabel)
        stackView.addArrangedSubview(buttonsStack)
        
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: statusLabel)
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: waveformView)
        stackView.setCustomSpacing(DesignTokens.Spacing.xl, after: resultLabel)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            waveformView.widthAnchor.constraint(equalToConstant: 120),
            waveformView.heightAnchor.constraint(equalToConstant: 40),
            resultLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 350),
            skipButton.widthAnchor.constraint(equalToConstant: 80),
            skipButton.heightAnchor.constraint(equalToConstant: 36),
            continueButton.widthAnchor.constraint(equalToConstant: 100),
            continueButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        setupRecording()
    }
    
    private func setupRecording() {
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
            statusLabel.stringValue = "Processing..."
            statusLabel.textColor = NSColor.swTextSecondary
            
            simulateTranscription(audioURL: url)
        }
    }
    
    private func simulateTranscription(audioURL: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.showTranscriptionResult("\"Hello, this is a test recording!\"")
            
            try? FileManager.default.removeItem(at: audioURL)
        }
    }
    
    private func showTranscriptionResult(_ text: String) {
        recordingCompleted = true
        
        statusLabel.stringValue = "Success!"
        statusLabel.textColor = NSColor.swSuccess
        
        resultLabel.stringValue = text
        resultLabel.isHidden = false
        
        continueButton.isHidden = false
        skipButton.isHidden = true
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
    
    convenience init(title: String, action: @escaping () -> Void) {
        self.init(frame: .zero)
        self.title = title
        self.actionHandler = action
        setup()
    }
    
    private func setup() {
        bezelStyle = .rounded
        isBordered = true
        font = DesignTokens.Typography.body(size: 13)
        target = self
        self.action = #selector(buttonClicked)
        
        wantsLayer = true
        layer?.cornerRadius = DesignTokens.CornerRadius.medium
    }
    
    @objc private func buttonClicked() {
        actionHandler?()
    }
}
