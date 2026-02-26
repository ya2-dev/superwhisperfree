import Cocoa

final class LanguagePreferencesView: NSView {
    
    private var languageMode: String = "english"
    private var selectedLanguage: String = "en"
    
    private var englishButton: NSButton!
    private var multilingualButton: NSButton!
    private var languageDropdownContainer: NSView!
    private var languageDropdown: NSPopUpButton!
    
    private let languages: [(code: String, name: String)] = [
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("ru", "Russian"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("vi", "Vietnamese"),
        ("tr", "Turkish")
    ]
    
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
        stackView.alignment = .leading
        stackView.spacing = DesignTokens.Spacing.lg
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let modeSection = createLanguageModeSection()
        languageDropdownContainer = createLanguageDropdownSection()
        
        stackView.addArrangedSubview(modeSection)
        stackView.addArrangedSubview(languageDropdownContainer)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.lg),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.lg)
        ])
        
        loadSettings()
        updateUI()
    }
    
    private func createLanguageModeSection() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.swSurface.cgColor
        container.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        
        let sectionLabel = NSTextField(labelWithString: "Language Mode")
        sectionLabel.font = DesignTokens.Typography.heading(size: 14)
        sectionLabel.textColor = NSColor.swText
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = NSTextField(labelWithString: "English Only is faster and more accurate for English speech")
        descriptionLabel.font = DesignTokens.Typography.body(size: 12)
        descriptionLabel.textColor = NSColor.swTextSecondary
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let buttonsStack = NSStackView()
        buttonsStack.orientation = .horizontal
        buttonsStack.alignment = .centerY
        buttonsStack.spacing = DesignTokens.Spacing.sm
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        
        englishButton = createModeButton(title: "English Only", isSelected: true)
        englishButton.target = self
        englishButton.action = #selector(englishModeSelected)
        
        multilingualButton = createModeButton(title: "Multilingual", isSelected: false)
        multilingualButton.target = self
        multilingualButton.action = #selector(multilingualModeSelected)
        
        buttonsStack.addArrangedSubview(englishButton)
        buttonsStack.addArrangedSubview(multilingualButton)
        
        container.addSubview(sectionLabel)
        container.addSubview(descriptionLabel)
        container.addSubview(buttonsStack)
        
        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.md),
            sectionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            sectionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.md),
            
            descriptionLabel.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            
            buttonsStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            buttonsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            buttonsStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.Spacing.md),
            
            container.widthAnchor.constraint(equalToConstant: 400)
        ])
        
        return container
    }
    
    private func createModeButton(title: String, isSelected: Bool) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.isBordered = false
        button.wantsLayer = true
        button.font = DesignTokens.Typography.body(size: 14)
        button.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        
        updateModeButtonAppearance(button, isSelected: isSelected)
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 130),
            button.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        return button
    }
    
    private func updateModeButtonAppearance(_ button: NSButton, isSelected: Bool) {
        if isSelected {
            button.layer?.backgroundColor = NSColor.swAccent.cgColor
            button.contentTintColor = NSColor.swBackground
            let attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .foregroundColor: NSColor.swBackground,
                    .font: DesignTokens.Typography.body(size: 14)
                ]
            )
            button.attributedTitle = attributedTitle
        } else {
            button.layer?.backgroundColor = NSColor.swSurfaceHover.cgColor
            button.contentTintColor = NSColor.swText
            let attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .foregroundColor: NSColor.swText,
                    .font: DesignTokens.Typography.body(size: 14)
                ]
            )
            button.attributedTitle = attributedTitle
        }
    }
    
    private func createLanguageDropdownSection() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.swSurface.cgColor
        container.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        
        let sectionLabel = NSTextField(labelWithString: "Select Language")
        sectionLabel.font = DesignTokens.Typography.heading(size: 14)
        sectionLabel.textColor = NSColor.swText
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = NSTextField(labelWithString: "Primary language for transcription")
        descriptionLabel.font = DesignTokens.Typography.body(size: 12)
        descriptionLabel.textColor = NSColor.swTextSecondary
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        languageDropdown = NSPopUpButton(frame: .zero, pullsDown: false)
        languageDropdown.font = DesignTokens.Typography.body(size: 14)
        languageDropdown.translatesAutoresizingMaskIntoConstraints = false
        languageDropdown.target = self
        languageDropdown.action = #selector(languageSelected(_:))
        
        for language in languages {
            languageDropdown.addItem(withTitle: language.name)
            languageDropdown.lastItem?.representedObject = language.code
        }
        
        container.addSubview(sectionLabel)
        container.addSubview(descriptionLabel)
        container.addSubview(languageDropdown)
        
        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.md),
            sectionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            sectionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.md),
            
            descriptionLabel.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            
            languageDropdown.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            languageDropdown.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            languageDropdown.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.Spacing.md),
            languageDropdown.widthAnchor.constraint(equalToConstant: 200),
            
            container.widthAnchor.constraint(equalToConstant: 400)
        ])
        
        return container
    }
    
    private func loadSettings() {
        let settings = SettingsManager.shared.settings
        languageMode = settings.languageMode
        selectedLanguage = settings.selectedLanguage
        
        if let index = languages.firstIndex(where: { $0.code == selectedLanguage }) {
            languageDropdown.selectItem(at: index)
        }
    }
    
    private func updateUI() {
        let isEnglish = languageMode == "english"
        
        updateModeButtonAppearance(englishButton, isSelected: isEnglish)
        updateModeButtonAppearance(multilingualButton, isSelected: !isEnglish)
        
        languageDropdownContainer.isHidden = isEnglish
        languageDropdownContainer.alphaValue = isEnglish ? 0 : 1
    }
    
    @objc private func englishModeSelected() {
        languageMode = "english"
        saveSettings()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            languageDropdownContainer.animator().alphaValue = 0
        } completionHandler: {
            self.updateUI()
        }
    }
    
    @objc private func multilingualModeSelected() {
        languageMode = "multilingual"
        saveSettings()
        
        languageDropdownContainer.isHidden = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            languageDropdownContainer.animator().alphaValue = 1
        } completionHandler: {
            self.updateUI()
        }
    }
    
    @objc private func languageSelected(_ sender: NSPopUpButton) {
        guard let code = sender.selectedItem?.representedObject as? String else { return }
        selectedLanguage = code
        saveSettings()
    }
    
    private func saveSettings() {
        SettingsManager.shared.settings.languageMode = languageMode
        SettingsManager.shared.settings.selectedLanguage = selectedLanguage
        SettingsManager.shared.save()
        NotificationCenter.default.post(name: .languageSettingsDidChange, object: nil)
    }
}
