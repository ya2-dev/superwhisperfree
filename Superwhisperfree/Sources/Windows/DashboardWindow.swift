import Cocoa

final class DashboardWindowController: NSWindowController {
    
    private var dashboardView: DashboardView!
    private var typingTestWindowController: TypingTestWindowController?
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Superwhisperfree Dashboard"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor.swBackground
        window.minSize = NSSize(width: 380, height: 500)
        
        self.init(window: window)
        
        dashboardView = DashboardView()
        dashboardView.translatesAutoresizingMaskIntoConstraints = false
        dashboardView.onTypingTestRequested = { [weak self] in
            self?.showTypingTest()
        }
        dashboardView.onPreferencesRequested = { [weak self] in
            self?.openPreferences()
        }
        
        guard let contentView = window.contentView else { return }
        contentView.addSubview(dashboardView)
        
        NSLayoutConstraint.activate([
            dashboardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            dashboardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dashboardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dashboardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func showTypingTest() {
        let typingTestController = TypingTestWindowController()
        typingTestController.onComplete = { [weak self] wpm in
            self?.dashboardView.refreshStats()
        }
        
        typingTestWindowController = typingTestController
        typingTestController.showWindow(nil)
        typingTestController.window?.makeKeyAndOrderFront(nil)
    }
    
    private func openPreferences() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.openPreferences()
        }
    }
    
    func refreshStats() {
        dashboardView.refreshStats()
    }
}
