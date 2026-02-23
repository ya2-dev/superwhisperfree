import Cocoa

enum HotkeyOption: String, CaseIterable {
    case rightOption = "rightOption"
    case rightCommand = "rightCommand"
    case fnKey = "fnKey"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .rightOption: return "Right Option (⌥)"
        case .rightCommand: return "Right Command (⌘)"
        case .fnKey: return "Fn key (double-press)"
        case .custom: return "Custom..."
        }
    }
    
    var isRecommended: Bool {
        return self == .rightOption
    }
    
    var isEnabled: Bool {
        return self != .custom
    }
    
    func toHotkeyConfig() -> HotkeyConfig {
        switch self {
        case .rightOption:
            return HotkeyConfig(modifiers: ["rightAlt"], key: "")
        case .rightCommand:
            return HotkeyConfig(modifiers: ["rightCmd"], key: "")
        case .fnKey:
            return HotkeyConfig(modifiers: ["fn"], key: "")
        case .custom:
            return HotkeyConfig.defaultHotkey
        }
    }
}

final class HotkeySelectionView: NSView {
    
    var onComplete: (() -> Void)?
    
    private var selectedOption: HotkeyOption = .rightOption
    private var radioButtons: [HotkeyOption: NSButton] = [:]
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = DesignTokens.Spacing.md
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = NSImageView()
        if let symbolImage = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard") {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
            iconImageView.image = symbolImage.withSymbolConfiguration(config)
            iconImageView.contentTintColor = NSColor.swAccent
        }
        
        let titleLabel = NSTextField(labelWithString: "Choose Your Hotkey")
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = NSColor.swText
        titleLabel.alignment = .center
        
        let subtitleLabel = NSTextField(wrappingLabelWithString: "Hold this key to record, release to transcribe")
        subtitleLabel.font = DesignTokens.Typography.body(size: 14)
        subtitleLabel.textColor = NSColor.swTextSecondary
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2
        
        let optionsContainer = createOptionsContainer()
        
        let continueButton = createButton(title: "Continue") { [weak self] in
            self?.saveAndContinue()
        }
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(optionsContainer)
        stackView.addArrangedSubview(continueButton)
        
        stackView.setCustomSpacing(DesignTokens.Spacing.sm, after: iconImageView)
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: subtitleLabel)
        stackView.setCustomSpacing(DesignTokens.Spacing.xl, after: optionsContainer)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 350),
            optionsContainer.widthAnchor.constraint(equalToConstant: 380),
            continueButton.widthAnchor.constraint(equalToConstant: 140),
            continueButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func createOptionsContainer() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.swSurface.cgColor
        container.layer?.cornerRadius = DesignTokens.CornerRadius.large
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = DesignTokens.Spacing.xs
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for option in HotkeyOption.allCases {
            let row = createOptionRow(option: option)
            stackView.addArrangedSubview(row)
        }
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.md),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.md),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.Spacing.md)
        ])
        
        return container
    }
    
    private func createOptionRow(option: HotkeyOption) -> NSView {
        let rowContainer = NSView()
        rowContainer.wantsLayer = true
        rowContainer.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        
        let radioButton = NSButton(radioButtonWithTitle: "", target: self, action: #selector(optionSelected(_:)))
        radioButton.identifier = NSUserInterfaceItemIdentifier(option.rawValue)
        radioButton.state = option == selectedOption ? .on : .off
        radioButton.isEnabled = option.isEnabled
        radioButtons[option] = radioButton
        
        let contentStack = NSStackView()
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = DesignTokens.Spacing.sm
        
        let nameLabel = NSTextField(labelWithString: option.displayName)
        nameLabel.font = DesignTokens.Typography.body(size: 14)
        nameLabel.textColor = option.isEnabled ? NSColor.swText : NSColor.swTextSecondary.withAlphaComponent(0.5)
        
        contentStack.addArrangedSubview(nameLabel)
        
        if option.isRecommended {
            let badge = createBadge(text: "Recommended", backgroundColor: NSColor.swSuccess.withAlphaComponent(0.2), textColor: NSColor.swSuccess)
            contentStack.addArrangedSubview(badge)
        }
        
        if !option.isEnabled {
            let badge = createBadge(text: "Coming soon", backgroundColor: NSColor.swSurfaceHover, textColor: NSColor.swTextSecondary)
            contentStack.addArrangedSubview(badge)
        }
        
        let mainStack = NSStackView()
        mainStack.orientation = .horizontal
        mainStack.alignment = .centerY
        mainStack.spacing = DesignTokens.Spacing.sm
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        mainStack.addArrangedSubview(radioButton)
        mainStack.addArrangedSubview(contentStack)
        
        rowContainer.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: rowContainer.topAnchor, constant: DesignTokens.Spacing.sm),
            mainStack.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor, constant: DesignTokens.Spacing.sm),
            mainStack.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor, constant: -DesignTokens.Spacing.sm),
            mainStack.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor, constant: -DesignTokens.Spacing.sm)
        ])
        
        return rowContainer
    }
    
    private func createBadge(text: String, backgroundColor: NSColor, textColor: NSColor) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = backgroundColor.cgColor
        container.layer?.cornerRadius = DesignTokens.CornerRadius.small
        
        let label = NSTextField(labelWithString: text)
        label.font = DesignTokens.Typography.body(size: 11)
        label.textColor = textColor
        label.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2)
        ])
        
        return container
    }
    
    private func createButton(title: String, action: @escaping () -> Void) -> NSButton {
        let button = HotkeyActionButton(title: title, action: action)
        return button
    }
    
    @objc private func optionSelected(_ sender: NSButton) {
        guard let optionId = sender.identifier?.rawValue,
              let option = HotkeyOption(rawValue: optionId),
              option.isEnabled else { return }
        
        for (opt, button) in radioButtons {
            button.state = opt == option ? .on : .off
        }
        
        selectedOption = option
    }
    
    private func saveAndContinue() {
        let hotkeyConfig = selectedOption.toHotkeyConfig()
        SettingsManager.shared.settings.hotkey = hotkeyConfig
        SettingsManager.shared.save()
        
        onComplete?()
    }
}

private class HotkeyActionButton: NSButton {
    
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
