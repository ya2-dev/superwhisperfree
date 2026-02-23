import Cocoa
import Carbon.HIToolbox

final class HotkeyManager {
    
    static let shared = HotkeyManager()
    
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?
    
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var isHotkeyPressed = false
    private var permissionCheckTimer: Timer?
    private var isMonitoringActive = false
    private var hasShownPermissionAlert = false
    
    private init() {
        setupAppActivationObserver()
    }
    
    private func setupAppActivationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        if isMonitoringActive && !hasAccessibilityPermission {
            print("HotkeyManager: App became active but lost accessibility permission")
            hasShownPermissionAlert = false
            stop()
            start()
        }
    }
    
    var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            showAccessibilityAlert()
        }
    }
    
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Superwhisperfree needs Accessibility permission to detect the hotkey.\n\nIf you've granted permission before but it's not working, click \"Reset & Open Settings\" to clear the old entry and add the app again."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Reset & Open Settings")
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn:
                self.resetAndOpenAccessibilitySettings()
            case .alertSecondButtonReturn:
                self.openAccessibilityPreferences()
            default:
                break
            }
        }
    }
    
    private func resetAndOpenAccessibilitySettings() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.superwhisperfree.app"
        
        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments = ["reset", "Accessibility", bundleId]
        
        do {
            try task.run()
            task.waitUntilExit()
            print("HotkeyManager: Reset accessibility permission for \(bundleId)")
        } catch {
            print("HotkeyManager: Failed to reset accessibility: \(error)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.openAccessibilityPreferences()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
            }
        }
    }
    
    func start() {
        stopPermissionCheckTimer()
        
        print("HotkeyManager: start() called")
        print("HotkeyManager: hasAccessibilityPermission = \(hasAccessibilityPermission)")
        
        guard hasAccessibilityPermission else {
            print("HotkeyManager: No accessibility permission, requesting...")
            requestAccessibilityPermission()
            startPermissionCheckTimer()
            return
        }
        
        stop()
        
        let hotkeyConfig = SettingsManager.shared.hotkeyConfig
        print("HotkeyManager: Config - useRightAlt=\(hotkeyConfig.useRightAlt), useRightCmd=\(hotkeyConfig.useRightCmd), useFnKey=\(hotkeyConfig.useFnKey)")
        
        if hotkeyConfig.useRightAlt {
            print("HotkeyManager: Starting right alt monitoring")
            startRightAltMonitoring()
        } else if hotkeyConfig.useRightCmd {
            print("HotkeyManager: Starting right cmd monitoring")
            startRightCmdMonitoring()
        } else if hotkeyConfig.useFnKey {
            print("HotkeyManager: Starting fn key monitoring")
            startFnKeyMonitoring()
        } else {
            print("HotkeyManager: Starting key monitoring for keyCode=\(hotkeyConfig.keyCode)")
            startKeyMonitoring(keyCode: hotkeyConfig.keyCode, modifiers: hotkeyConfig.modifiers)
        }
        
        isMonitoringActive = true
        print("HotkeyManager: Monitoring active = \(isMonitoringActive)")
    }
    
    private var permissionCheckCount = 0
    
    private func startPermissionCheckTimer() {
        permissionCheckCount = 0
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.permissionCheckCount += 1
            
            if self.hasAccessibilityPermission {
                self.stopPermissionCheckTimer()
                self.hasShownPermissionAlert = false
                self.start()
            } else if self.permissionCheckCount >= 3 && !self.hasShownPermissionAlert {
                self.hasShownPermissionAlert = true
                self.showAccessibilityAlert()
            }
        }
    }
    
    private func stopPermissionCheckTimer() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    func stop() {
        stopPermissionCheckTimer()
        
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        isHotkeyPressed = false
        isMonitoringActive = false
    }
    
    func restart() {
        stop()
        start()
    }
    
    private func startRightAltMonitoring() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleRightAltEvent(event)
        }
    }
    
    private func handleRightAltEvent(_ event: NSEvent) {
        let rightAltKeyCode: UInt16 = 61
        
        print("HotkeyManager: flagsChanged event - keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)")
        
        guard event.keyCode == rightAltKeyCode else { return }
        
        let isPressed = event.modifierFlags.contains(.option)
        print("HotkeyManager: Right Alt detected - isPressed=\(isPressed), wasPressed=\(isHotkeyPressed)")
        
        if isPressed && !isHotkeyPressed {
            isHotkeyPressed = true
            print("HotkeyManager: Triggering onHotkeyDown")
            onHotkeyDown?()
        } else if !isPressed && isHotkeyPressed {
            isHotkeyPressed = false
            print("HotkeyManager: Triggering onHotkeyUp")
            onHotkeyUp?()
        }
    }
    
    private func startRightCmdMonitoring() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleRightCmdEvent(event)
        }
    }
    
    private func handleRightCmdEvent(_ event: NSEvent) {
        let rightCmdKeyCode: UInt16 = 54
        
        guard event.keyCode == rightCmdKeyCode else { return }
        
        let isPressed = event.modifierFlags.contains(.command)
        
        if isPressed && !isHotkeyPressed {
            isHotkeyPressed = true
            onHotkeyDown?()
        } else if !isPressed && isHotkeyPressed {
            isHotkeyPressed = false
            onHotkeyUp?()
        }
    }
    
    private var lastFnPressTime: Date?
    private let fnDoublePressInterval: TimeInterval = 0.4
    
    private func startFnKeyMonitoring() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFnKeyEvent(event)
        }
    }
    
    private func handleFnKeyEvent(_ event: NSEvent) {
        let isFnPressed = event.modifierFlags.contains(.function)
        
        if isFnPressed && !isHotkeyPressed {
            let now = Date()
            if let lastPress = lastFnPressTime, now.timeIntervalSince(lastPress) < fnDoublePressInterval {
                isHotkeyPressed = true
                onHotkeyDown?()
                lastFnPressTime = nil
            } else {
                lastFnPressTime = now
            }
        } else if !isFnPressed && isHotkeyPressed {
            isHotkeyPressed = false
            onHotkeyUp?()
        }
    }
    
    private func startKeyMonitoring(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleKeyEvent(event, expectedKeyCode: keyCode, expectedModifiers: modifiers)
        }
        
        if !modifiers.isEmpty {
            flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleModifierRelease(event, expectedModifiers: modifiers)
            }
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent, expectedKeyCode: UInt16, expectedModifiers: NSEvent.ModifierFlags) {
        guard event.keyCode == expectedKeyCode else { return }
        
        let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let currentModifiers = event.modifierFlags.intersection(relevantModifiers)
        
        guard currentModifiers == expectedModifiers else { return }
        
        if event.type == .keyDown && !isHotkeyPressed {
            isHotkeyPressed = true
            onHotkeyDown?()
        } else if event.type == .keyUp && isHotkeyPressed {
            isHotkeyPressed = false
            onHotkeyUp?()
        }
    }
    
    private func handleModifierRelease(_ event: NSEvent, expectedModifiers: NSEvent.ModifierFlags) {
        guard isHotkeyPressed else { return }
        
        let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let currentModifiers = event.modifierFlags.intersection(relevantModifiers)
        
        if !currentModifiers.contains(expectedModifiers) {
            isHotkeyPressed = false
            onHotkeyUp?()
        }
    }
}

