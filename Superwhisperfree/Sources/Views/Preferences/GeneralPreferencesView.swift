import Cocoa

final class GeneralPreferencesView: NSView {
    
    private let startOnLoginCheckbox = NSButton(checkboxWithTitle: "Start on Login", target: nil, action: nil)
    private let hotkeyLabel = NSTextField(labelWithString: "")
    private let changeHotkeyButton = NSButton(title: "Change...", target: nil, action: nil)
    
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
        
        let startupSection = createStartupSection()
        let hotkeySection = createHotkeySection()
        
        stackView.addArrangedSubview(startupSection)
        stackView.addArrangedSubview(hotkeySection)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.lg),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.lg)
        ])
        
        loadSettings()
    }
    
    private func createStartupSection() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.swSurface.cgColor
        container.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        
        let sectionLabel = NSTextField(labelWithString: "Startup")
        sectionLabel.font = DesignTokens.Typography.heading(size: 14)
        sectionLabel.textColor = NSColor.swText
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        startOnLoginCheckbox.font = DesignTokens.Typography.body(size: 14)
        startOnLoginCheckbox.contentTintColor = NSColor.swText
        startOnLoginCheckbox.target = self
        startOnLoginCheckbox.action = #selector(startOnLoginChanged(_:))
        startOnLoginCheckbox.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(sectionLabel)
        container.addSubview(startOnLoginCheckbox)
        
        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.md),
            sectionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            sectionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.md),
            
            startOnLoginCheckbox.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            startOnLoginCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            startOnLoginCheckbox.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.Spacing.md),
            
            container.widthAnchor.constraint(equalToConstant: 400)
        ])
        
        return container
    }
    
    private func createHotkeySection() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.swSurface.cgColor
        container.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        
        let sectionLabel = NSTextField(labelWithString: "Hotkey")
        sectionLabel.font = DesignTokens.Typography.heading(size: 14)
        sectionLabel.textColor = NSColor.swText
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = NSTextField(labelWithString: "Hold this key to record, release to transcribe")
        descriptionLabel.font = DesignTokens.Typography.body(size: 12)
        descriptionLabel.textColor = NSColor.swTextSecondary
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let hotkeyRow = NSStackView()
        hotkeyRow.orientation = .horizontal
        hotkeyRow.alignment = .centerY
        hotkeyRow.spacing = DesignTokens.Spacing.md
        hotkeyRow.translatesAutoresizingMaskIntoConstraints = false
        
        hotkeyLabel.font = DesignTokens.Typography.mono(size: 14)
        hotkeyLabel.textColor = NSColor.swText
        hotkeyLabel.backgroundColor = NSColor.swSurfaceHover
        hotkeyLabel.isBordered = false
        hotkeyLabel.isEditable = false
        hotkeyLabel.alignment = .center
        hotkeyLabel.wantsLayer = true
        hotkeyLabel.layer?.cornerRadius = DesignTokens.CornerRadius.small
        hotkeyLabel.layer?.backgroundColor = NSColor.swSurfaceHover.cgColor
        
        changeHotkeyButton.bezelStyle = .rounded
        changeHotkeyButton.font = DesignTokens.Typography.body(size: 13)
        changeHotkeyButton.target = self
        changeHotkeyButton.action = #selector(changeHotkeyClicked)
        
        hotkeyRow.addArrangedSubview(hotkeyLabel)
        hotkeyRow.addArrangedSubview(changeHotkeyButton)
        
        container.addSubview(sectionLabel)
        container.addSubview(descriptionLabel)
        container.addSubview(hotkeyRow)
        
        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.md),
            sectionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            sectionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.md),
            
            descriptionLabel.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            
            hotkeyRow.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            hotkeyRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            hotkeyRow.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.Spacing.md),
            
            hotkeyLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            hotkeyLabel.heightAnchor.constraint(equalToConstant: 28),
            
            container.widthAnchor.constraint(equalToConstant: 400)
        ])
        
        return container
    }
    
    private func loadSettings() {
        let settings = SettingsManager.shared.settings
        startOnLoginCheckbox.state = settings.startOnLogin ? .on : .off
        hotkeyLabel.stringValue = formatHotkey(settings.hotkey)
    }
    
    private func formatHotkey(_ hotkey: HotkeyConfig) -> String {
        if hotkey.modifiers.contains("rightAlt") && hotkey.key.isEmpty {
            return "Right Option (⌥)"
        }
        if hotkey.modifiers.contains("rightCmd") && hotkey.key.isEmpty {
            return "Right Command (⌘)"
        }
        if hotkey.modifiers.contains("fn") && hotkey.key.isEmpty {
            return "Fn key (double-press)"
        }
        
        var parts: [String] = []
        for modifier in hotkey.modifiers {
            switch modifier.lowercased() {
            case "command", "cmd": parts.append("⌘")
            case "option", "alt": parts.append("⌥")
            case "control", "ctrl": parts.append("⌃")
            case "shift": parts.append("⇧")
            default: break
            }
        }
        if !hotkey.key.isEmpty {
            parts.append(hotkey.key.uppercased())
        }
        return parts.isEmpty ? "Not set" : parts.joined(separator: " ")
    }
    
    @objc private func startOnLoginChanged(_ sender: NSButton) {
        SettingsManager.shared.settings.startOnLogin = sender.state == .on
        SettingsManager.shared.save()
    }
    
    @objc private func changeHotkeyClicked() {
        let alert = NSAlert()
        alert.messageText = "Change Hotkey"
        alert.informativeText = "Hotkey customization will be available in a future update. Currently supported:\n\n• Right Option (⌥)\n• Right Command (⌘)\n• Fn key (double-press)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
