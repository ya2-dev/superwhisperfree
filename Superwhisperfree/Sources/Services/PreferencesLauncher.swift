import Cocoa

final class PreferencesLauncher {
    static func openPreferences() {
        // Native preferences - TODO: implement native preferences window
        let alert = NSAlert()
        alert.messageText = "Preferences"
        alert.informativeText = "Model selection and settings are available in the main dashboard."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
