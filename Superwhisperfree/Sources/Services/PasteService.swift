import Cocoa
import Carbon.HIToolbox

final class PasteService {
    
    static let shared = PasteService()
    
    private init() {}
    
    func pasteText(_ text: String) {
        setClipboard(text)
        simulatePaste()
    }
    
    private func setClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDownEvent?.flags = .maskCommand
        
        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUpEvent?.flags = .maskCommand
        
        keyDownEvent?.post(tap: .cghidEventTap)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            keyUpEvent?.post(tap: .cghidEventTap)
        }
    }
}
