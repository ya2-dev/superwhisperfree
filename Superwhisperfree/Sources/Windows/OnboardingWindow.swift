import Cocoa

final class OnboardingWindowController: NSWindowController {
    
    enum Step: Int, CaseIterable {
        case welcome
        case feature1
        case feature2
        case feature3
        case feature4
        case modelSelection
        case hotkeySelection
        case setup
        case testRecording
        case done
    }
    
    private var currentStep: Step = .welcome
    private var contentView: NSView?
    
    var onComplete: (() -> Void)?
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 700),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Superwhisperfree"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor.swBackground
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.swBackground.cgColor
        
        self.init(window: window)
        showStep(.welcome)
    }
    
    func showStep(_ step: Step) {
        currentStep = step
        
        contentView?.removeFromSuperview()
        
        let newContent: NSView
        
        switch step {
        case .welcome:
            newContent = createWelcomeView()
        case .feature1:
            newContent = createFeatureView(
                icon: "waveform",
                title: "Hold to Record",
                description: "Press and hold your hotkey to start recording. Release to stop and transcribe instantly.",
                currentIndex: 0
            )
        case .feature2:
            newContent = createFeatureView(
                icon: "text.bubble",
                title: "Instant Transcription",
                description: "Your speech is transcribed locally using advanced AI models. No internet required.",
                currentIndex: 1
            )
        case .feature3:
            newContent = createFeatureView(
                icon: "doc.on.clipboard",
                title: "Paste Anywhere",
                description: "Transcribed text is automatically copied to your clipboard and pasted into the active app.",
                currentIndex: 2
            )
        case .feature4:
            newContent = createFeatureView(
                icon: "chart.line.uptrend.xyaxis",
                title: "Track Productivity",
                description: "Monitor your dictation usage with daily and weekly statistics in the dashboard.",
                currentIndex: 3
            )
        case .modelSelection:
            showModelSelection()
            return
        case .hotkeySelection:
            showHotkeySelection()
            return
        case .setup:
            let setupView = SetupView()
            setupView.onComplete = { [weak self] in
                self?.showStep(.testRecording)
            }
            newContent = setupView
        case .testRecording:
            let testView = TestRecordingView()
            testView.onComplete = { [weak self] in
                self?.showStep(.done)
            }
            newContent = testView
        case .done:
            completeOnboarding()
            return
        }
        
        guard let windowContentView = window?.contentView else { return }
        
        newContent.translatesAutoresizingMaskIntoConstraints = false
        windowContentView.addSubview(newContent)
        
        NSLayoutConstraint.activate([
            newContent.topAnchor.constraint(equalTo: windowContentView.topAnchor),
            newContent.leadingAnchor.constraint(equalTo: windowContentView.leadingAnchor),
            newContent.trailingAnchor.constraint(equalTo: windowContentView.trailingAnchor),
            newContent.bottomAnchor.constraint(equalTo: windowContentView.bottomAnchor)
        ])
        
        contentView = newContent
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            newContent.animator().alphaValue = 1.0
        }
    }
    
    private func createWelcomeView() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = DesignTokens.Spacing.md
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Superwhisperfree")
        titleLabel.font = DesignTokens.Typography.heading(size: 32)
        titleLabel.textColor = NSColor.swText
        titleLabel.alignment = .center
        
        let subtitleLabel = NSTextField(labelWithString: "Local offline dictation.\nHold a key to record.")
        subtitleLabel.font = DesignTokens.Typography.body(size: 16)
        subtitleLabel.textColor = NSColor.swTextSecondary
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2
        
        let getStartedButton = createButton(title: "Get Started") { [weak self] in
            self?.showStep(.feature1)
        }
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(NSView())
        stackView.addArrangedSubview(getStartedButton)
        
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: subtitleLabel)
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: DesignTokens.Spacing.xl),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            getStartedButton.widthAnchor.constraint(equalToConstant: 140),
            getStartedButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return container
    }
    
    private func createFeatureView(icon: String, title: String, description: String, currentIndex: Int) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = DesignTokens.Spacing.md
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = NSImageView()
        if let symbolImage = NSImage(systemSymbolName: icon, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
            iconImageView.image = symbolImage.withSymbolConfiguration(config)
            iconImageView.contentTintColor = NSColor.swAccent
        }
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = NSColor.swText
        titleLabel.alignment = .center
        
        let descriptionLabel = NSTextField(wrappingLabelWithString: description)
        descriptionLabel.font = DesignTokens.Typography.body(size: 14)
        descriptionLabel.textColor = NSColor.swTextSecondary
        descriptionLabel.alignment = .center
        descriptionLabel.maximumNumberOfLines = 3
        
        let dotsView = createDotsIndicator(currentIndex: currentIndex, totalDots: 4)
        
        let continueButton = createButton(title: "Continue") { [weak self] in
            guard let self = self else { return }
            let nextStep = Step(rawValue: self.currentStep.rawValue + 1) ?? .setup
            self.showStep(nextStep)
        }
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(dotsView)
        stackView.addArrangedSubview(continueButton)
        
        stackView.setCustomSpacing(DesignTokens.Spacing.sm, after: iconImageView)
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: descriptionLabel)
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: dotsView)
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: DesignTokens.Spacing.xl),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            descriptionLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            continueButton.widthAnchor.constraint(equalToConstant: 120),
            continueButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        return container
    }
    
    private func createDotsIndicator(currentIndex: Int, totalDots: Int) -> NSView {
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = DesignTokens.Spacing.sm
        
        for i in 0..<totalDots {
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = (i == currentIndex ? NSColor.swAccent : NSColor.swSurface).cgColor
            dot.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8)
            ])
            
            stackView.addArrangedSubview(dot)
        }
        
        return stackView
    }
    
    private func createButton(title: String, action: @escaping () -> Void) -> NSButton {
        let button = ActionButton(title: title, action: action)
        return button
    }
    
    private func showModelSelection() {
        let modelView = ModelSelectionView()
        modelView.translatesAutoresizingMaskIntoConstraints = false
        modelView.onComplete = { [weak self] in
            self?.showStep(.hotkeySelection)
        }
        
        guard let windowContentView = window?.contentView else { return }
        windowContentView.addSubview(modelView)
        
        NSLayoutConstraint.activate([
            modelView.topAnchor.constraint(equalTo: windowContentView.topAnchor),
            modelView.leadingAnchor.constraint(equalTo: windowContentView.leadingAnchor),
            modelView.trailingAnchor.constraint(equalTo: windowContentView.trailingAnchor),
            modelView.bottomAnchor.constraint(equalTo: windowContentView.bottomAnchor)
        ])
        
        contentView = modelView
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            modelView.animator().alphaValue = 1.0
        }
    }
    
    private func showHotkeySelection() {
        let hotkeyView = HotkeySelectionView()
        hotkeyView.translatesAutoresizingMaskIntoConstraints = false
        hotkeyView.onComplete = { [weak self] in
            self?.showStep(.setup)
        }
        
        guard let windowContentView = window?.contentView else { return }
        windowContentView.addSubview(hotkeyView)
        
        NSLayoutConstraint.activate([
            hotkeyView.topAnchor.constraint(equalTo: windowContentView.topAnchor),
            hotkeyView.leadingAnchor.constraint(equalTo: windowContentView.leadingAnchor),
            hotkeyView.trailingAnchor.constraint(equalTo: windowContentView.trailingAnchor),
            hotkeyView.bottomAnchor.constraint(equalTo: windowContentView.bottomAnchor)
        ])
        
        contentView = hotkeyView
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            hotkeyView.animator().alphaValue = 1.0
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        onComplete?()
        close()
    }
}

private class ActionButton: NSButton {
    
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
        font = DesignTokens.Typography.body(size: 14)
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
