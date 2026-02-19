import Cocoa
import ApplicationServices

final class SetupView: NSView {
    
    var onComplete: (() -> Void)?
    
    private var statusTimer: Timer?
    private var hasPromptedForAccessibility = false
    private var accessibilityGrantedAtStartup: Bool = false
    
    private let accessibilityStatusLabel = NSTextField(labelWithString: "⏳ Not granted")
    private let modelStatusLabel = NSTextField(labelWithString: "⏳ Model not downloaded")
    private let hotkeyStatusLabel = NSTextField(labelWithString: "⏳ Hotkey not set")
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    deinit {
        statusTimer?.invalidate()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && !hasPromptedForAccessibility && !AXIsProcessTrusted() {
            hasPromptedForAccessibility = true
            requestAccessibilityPermission()
        }
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    private func setup() {
        wantsLayer = true
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = DesignTokens.Spacing.md
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Setup")
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = NSColor.swText
        titleLabel.alignment = .center
        
        let descriptionLabel = NSTextField(wrappingLabelWithString: "Grant accessibility permission and configure your hotkey to get started.")
        descriptionLabel.font = DesignTokens.Typography.body(size: 14)
        descriptionLabel.textColor = NSColor.swTextSecondary
        descriptionLabel.alignment = .center
        descriptionLabel.maximumNumberOfLines = 2
        
        let buttonsStack = NSStackView()
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = DesignTokens.Spacing.md
        
        let requestPermissionButton = SWButton(title: "Request Permission", style: .secondary) { [weak self] in
            self?.requestAccessibilityPermission()
        }
        
        let accessibilityButton = SWButton(title: "Open Accessibility Settings", style: .secondary) { [weak self] in
            self?.openAccessibilitySettings()
        }
        
        let preferencesButton = SWButton(title: "Open Preferences", style: .secondary) { [weak self] in
            self?.openPreferences()
        }
        
        buttonsStack.addArrangedSubview(requestPermissionButton)
        buttonsStack.addArrangedSubview(accessibilityButton)
        buttonsStack.addArrangedSubview(preferencesButton)
        
        let statusStack = createStatusStack()
        
        let doneButton = SWButton(title: "I'm Done", style: .primary) { [weak self] in
            self?.onComplete?()
        }
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(buttonsStack)
        stackView.addArrangedSubview(statusStack)
        stackView.addArrangedSubview(doneButton)
        
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: descriptionLabel)
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: buttonsStack)
        stackView.setCustomSpacing(DesignTokens.Spacing.xl, after: statusStack)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            descriptionLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 350),
            doneButton.widthAnchor.constraint(equalToConstant: 120),
            doneButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        startStatusTimer()
        updateStatuses()
    }
    
    private func createStatusStack() -> NSView {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = DesignTokens.Spacing.sm
        
        configureStatusLabel(accessibilityStatusLabel)
        configureStatusLabel(modelStatusLabel)
        configureStatusLabel(hotkeyStatusLabel)
        
        stackView.addArrangedSubview(createStatusRow(label: "Accessibility:", statusLabel: accessibilityStatusLabel))
        stackView.addArrangedSubview(createStatusRow(label: "Model:", statusLabel: modelStatusLabel))
        stackView.addArrangedSubview(createStatusRow(label: "Hotkey:", statusLabel: hotkeyStatusLabel))
        
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.swSurface.cgColor
        container.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.md),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.md),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.Spacing.md)
        ])
        
        return container
    }
    
    private func createStatusRow(label: String, statusLabel: NSTextField) -> NSView {
        let rowStack = NSStackView()
        rowStack.orientation = .horizontal
        rowStack.spacing = DesignTokens.Spacing.sm
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignTokens.Typography.body(size: 13)
        labelField.textColor = NSColor.swTextSecondary
        labelField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        rowStack.addArrangedSubview(labelField)
        rowStack.addArrangedSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            labelField.widthAnchor.constraint(equalToConstant: 90)
        ])
        
        return rowStack
    }
    
    private func configureStatusLabel(_ label: NSTextField) {
        label.font = DesignTokens.Typography.body(size: 13)
        label.textColor = NSColor.swTextSecondary
    }
    
    private func startStatusTimer() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatuses()
        }
    }
    
    private func updateStatuses() {
        updateAccessibilityStatus()
        updateModelStatus()
        updateHotkeyStatus()
    }
    
    private func updateAccessibilityStatus() {
        checkAccessibilityWithFreshProcess { [weak self] trusted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if trusted {
                    self.accessibilityStatusLabel.stringValue = "✓ Accessibility granted"
                    self.accessibilityStatusLabel.textColor = NSColor.swSuccess
                } else {
                    self.accessibilityStatusLabel.stringValue = "⏳ Not granted (restart app after granting)"
                    self.accessibilityStatusLabel.textColor = NSColor.swTextSecondary
                }
            }
        }
    }
    
    private func checkAccessibilityWithFreshProcess(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "tell application \"System Events\" to return (exists window 1 of application process \"Finder\")"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let trusted = process.terminationStatus == 0
                completion(trusted)
            } catch {
                let fallback = AXIsProcessTrusted()
                completion(fallback)
            }
        }
    }
    
    private func updateModelStatus() {
        let modelReady = checkModelReady()
        if modelReady {
            modelStatusLabel.stringValue = "✓ Model ready"
            modelStatusLabel.textColor = NSColor.swSuccess
        } else {
            modelStatusLabel.stringValue = "⏳ Model not downloaded"
            modelStatusLabel.textColor = NSColor.swTextSecondary
        }
    }
    
    private func updateHotkeyStatus() {
        let settings = SettingsManager.shared.settings
        let hotkeyConfigured = !settings.hotkey.key.isEmpty || !settings.hotkey.modifiers.isEmpty
        if hotkeyConfigured {
            hotkeyStatusLabel.stringValue = "✓ Hotkey configured"
            hotkeyStatusLabel.textColor = NSColor.swSuccess
        } else {
            hotkeyStatusLabel.stringValue = "⏳ Hotkey not set"
            hotkeyStatusLabel.textColor = NSColor.swTextSecondary
        }
    }
    
    private func checkModelReady() -> Bool {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("Superwhisperfree/models", isDirectory: true)
        
        if fileManager.fileExists(atPath: modelsDir.path) {
            let contents = try? fileManager.contentsOfDirectory(atPath: modelsDir.path)
            return contents?.isEmpty == false
        }
        return false
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openPreferences() {
        PreferencesLauncher.openPreferences()
    }
}
