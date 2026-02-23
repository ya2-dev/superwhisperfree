import Cocoa
import ServiceManagement

protocol MenuBarControllerDelegate: AnyObject {
    func menuBarControllerDidRequestDashboard(_ controller: MenuBarController)
    func menuBarControllerDidRequestWelcome(_ controller: MenuBarController)
    func menuBarControllerDidRequestPreferences(_ controller: MenuBarController)
}

final class MenuBarController: NSObject {
    
    weak var delegate: MenuBarControllerDelegate?
    
    private var statusItem: NSStatusItem?
    private var startOnLoginMenuItem: NSMenuItem?
    private var isRecording = false
    
    override init() {
        super.init()
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = createWaveformIcon()
            button.image?.isTemplate = true
            button.toolTip = "Superwhisperfree - Hold hotkey to dictate"
        }
        
        statusItem?.menu = createMenu()
    }
    
    private func createWaveformIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let barWidth: CGFloat = 2
            let spacing: CGFloat = 2
            let heights: [CGFloat] = [0.3, 0.6, 1.0, 0.6, 0.3]
            let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * spacing
            let startX = (rect.width - totalWidth) / 2
            let maxHeight = rect.height - 4
            
            NSColor.black.setFill()
            
            for (index, heightRatio) in heights.enumerated() {
                let x = startX + CGFloat(index) * (barWidth + spacing)
                let barHeight = maxHeight * heightRatio
                let y = (rect.height - barHeight) / 2
                let barRect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
                let path = NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2)
                path.fill()
            }
            
            return true
        }
        
        return image
    }
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        let dashboardItem = NSMenuItem(
            title: "Open Dashboard",
            action: #selector(openDashboard),
            keyEquivalent: "d"
        )
        dashboardItem.target = self
        menu.addItem(dashboardItem)
        
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let startOnLoginItem = NSMenuItem(
            title: "Start on Login",
            action: #selector(toggleStartOnLogin),
            keyEquivalent: ""
        )
        startOnLoginItem.target = self
        startOnLoginItem.state = SettingsManager.shared.settings.startOnLogin ? .on : .off
        self.startOnLoginMenuItem = startOnLoginItem
        menu.addItem(startOnLoginItem)
        
        let showWelcomeItem = NSMenuItem(
            title: "Show Welcome Again",
            action: #selector(showWelcome),
            keyEquivalent: ""
        )
        showWelcomeItem.target = self
        menu.addItem(showWelcomeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let accessibilityItem = NSMenuItem(
            title: "Grant Accessibility Permission...",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit Superwhisperfree",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    @objc private func openDashboard() {
        delegate?.menuBarControllerDidRequestDashboard(self)
    }
    
    @objc private func openPreferences() {
        delegate?.menuBarControllerDidRequestPreferences(self)
    }
    
    @objc private func toggleStartOnLogin() {
        var settings = SettingsManager.shared.settings
        settings.startOnLogin.toggle()
        SettingsManager.shared.settings = settings
        SettingsManager.shared.save()
        
        startOnLoginMenuItem?.state = settings.startOnLogin ? .on : .off
        
        updateLoginItem(enabled: settings.startOnLogin)
    }
    
    @objc private func showWelcome() {
        delegate?.menuBarControllerDidRequestWelcome(self)
    }
    
    @objc private func openAccessibilitySettings() {
        HotkeyManager.shared.openAccessibilityPreferences()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func updateLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update login item: \(error)")
            }
        }
    }
    
    func updateIcon(isRecording: Bool) {
        guard self.isRecording != isRecording else { return }
        self.isRecording = isRecording
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.statusItem?.button else { return }
            
            if isRecording {
                button.image = self.createRecordingIcon()
                button.toolTip = "Superwhisperfree - Recording..."
            } else {
                button.image = self.createWaveformIcon()
                button.toolTip = "Superwhisperfree - Hold hotkey to dictate"
            }
            button.image?.isTemplate = true
        }
    }
    
    private func createRecordingIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            let circleSize: CGFloat = 10
            let circleRect = NSRect(
                x: (rect.width - circleSize) / 2,
                y: (rect.height - circleSize) / 2,
                width: circleSize,
                height: circleSize
            )
            let path = NSBezierPath(ovalIn: circleRect)
            path.fill()
            return true
        }
        return image
    }
}
