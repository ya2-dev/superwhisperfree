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
    
    private init() {}
    
    var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    func start() {
        stopPermissionCheckTimer()
        
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            startPermissionCheckTimer()
            return
        }
        
        stop()
        
        let hotkeyConfig = SettingsManager.shared.hotkeyConfig
        
        if hotkeyConfig.useRightAlt {
            startRightAltMonitoring()
        } else if hotkeyConfig.useRightCmd {
            startRightCmdMonitoring()
        } else if hotkeyConfig.useFnKey {
            startFnKeyMonitoring()
        } else {
            startKeyMonitoring(keyCode: hotkeyConfig.keyCode, modifiers: hotkeyConfig.modifiers)
        }
        
        isMonitoringActive = true
    }
    
    private func startPermissionCheckTimer() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.hasAccessibilityPermission {
                self.stopPermissionCheckTimer()
                self.start()
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
        
        guard event.keyCode == rightAltKeyCode else { return }
        
        let isPressed = event.modifierFlags.contains(.option)
        
        if isPressed && !isHotkeyPressed {
            isHotkeyPressed = true
            onHotkeyDown?()
        } else if !isPressed && isHotkeyPressed {
            isHotkeyPressed = false
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

