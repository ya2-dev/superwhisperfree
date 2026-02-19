import Cocoa
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var menuBarController: MenuBarController?
    private var onboardingWindowController: OnboardingWindowController?
    private var dashboardWindowController: NSWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    private var recordingCoordinator: RecordingCoordinator?
    
    private var recordingStateObserver: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupNotificationObservers()
        
        let onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")
        if onboardingComplete {
            startRecordingServices()
        } else {
            showOnboarding()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        stopRecordingServices()
        TranscriptionClient.shared.stop()
        SettingsManager.shared.save()
        removeNotificationObservers()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    private func setupMenuBar() {
        menuBarController = MenuBarController()
        menuBarController?.delegate = self
    }
    
    private func setupNotificationObservers() {
        recordingStateObserver = NotificationCenter.default.addObserver(
            forName: .recordingStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let isRecording = notification.userInfo?["isRecording"] as? Bool {
                self?.menuBarController?.updateIcon(isRecording: isRecording)
            }
        }
    }
    
    private func removeNotificationObservers() {
        if let observer = recordingStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func startRecordingServices() {
        recordingCoordinator = RecordingCoordinator.shared
        recordingCoordinator?.start()
    }
    
    private func stopRecordingServices() {
        recordingCoordinator?.stop()
    }
    
    func showOnboarding() {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController()
            onboardingWindowController?.onComplete = { [weak self] in
                self?.completeOnboarding()
            }
        }
        
        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showDashboard() {
        if dashboardWindowController == nil {
            dashboardWindowController = DashboardWindowController()
        }
        
        dashboardWindowController?.showWindow(nil)
        dashboardWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        onboardingWindowController?.close()
        onboardingWindowController = nil
        
        startRecordingServices()
        showDashboard()
    }
    
    func resetOnboarding() {
        stopRecordingServices()
        
        UserDefaults.standard.set(false, forKey: "onboardingComplete")
        dashboardWindowController?.close()
        showOnboarding()
    }
    
    @objc func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: MenuBarControllerDelegate {
    func menuBarControllerDidRequestDashboard(_ controller: MenuBarController) {
        showDashboard()
    }
    
    func menuBarControllerDidRequestWelcome(_ controller: MenuBarController) {
        resetOnboarding()
    }
    
    func menuBarControllerDidRequestPreferences(_ controller: MenuBarController) {
        openPreferences()
    }
}

extension Notification.Name {
    static let recordingStateDidChange = Notification.Name("recordingStateDidChange")
}
