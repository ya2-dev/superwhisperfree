import Cocoa

final class RecordingOverlay: NSPanel {
    
    enum State {
        case recording
        case transcribing
        case success
        case error(String)
    }
    
    private let visualEffectView: NSVisualEffectView
    private let waveformView: WaveformView
    private let statusLabel: NSTextField
    private let iconView: NSImageView
    
    private(set) var state: State = .recording {
        didSet {
            updateUI()
        }
    }
    
    init() {
        visualEffectView = NSVisualEffectView()
        waveformView = WaveformView()
        statusLabel = NSTextField(labelWithString: "")
        iconView = NSImageView()
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupPanel()
        setupViews()
    }
    
    private func setupPanel() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
    }
    
    private func setupViews() {
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.alphaValue = 0.95
        
        contentView = visualEffectView
        
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(waveformView)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.alignment = .center
        visualEffectView.addSubview(statusLabel)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = .white
        iconView.isHidden = true
        visualEffectView.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            waveformView.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor),
            waveformView.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor, constant: -10),
            waveformView.widthAnchor.constraint(equalToConstant: 60),
            waveformView.heightAnchor.constraint(equalToConstant: 30),
            
            iconView.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor, constant: -10),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            statusLabel.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -12),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: visualEffectView.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: visualEffectView.trailingAnchor, constant: -8)
        ])
        
        updateUI()
    }
    
    private func updateUI() {
        switch state {
        case .recording:
            waveformView.isHidden = false
            iconView.isHidden = true
            statusLabel.stringValue = "Recording..."
            statusLabel.textColor = .white
            
        case .transcribing:
            waveformView.isHidden = true
            iconView.isHidden = false
            iconView.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil)
            statusLabel.stringValue = "Transcribing..."
            statusLabel.textColor = .white
            startTranscribingAnimation()
            
        case .success:
            waveformView.isHidden = true
            iconView.isHidden = false
            iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
            iconView.contentTintColor = NSColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1.0)
            statusLabel.stringValue = "Done"
            statusLabel.textColor = .white
            stopTranscribingAnimation()
            
        case .error(let message):
            waveformView.isHidden = true
            iconView.isHidden = false
            iconView.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
            iconView.contentTintColor = NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
            statusLabel.stringValue = message
            statusLabel.textColor = NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
            stopTranscribingAnimation()
        }
    }
    
    private var transcribingAnimationTimer: Timer?
    
    private func startTranscribingAnimation() {
        stopTranscribingAnimation()
        
        var rotation: CGFloat = 0
        transcribingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            rotation += 30
            self?.iconView.layer?.setAffineTransform(CGAffineTransform(rotationAngle: rotation * .pi / 180))
        }
    }
    
    private func stopTranscribingAnimation() {
        transcribingAnimationTimer?.invalidate()
        transcribingAnimationTimer = nil
        iconView.layer?.setAffineTransform(.identity)
    }
    
    func showNearCursor() {
        let mouseLocation = NSEvent.mouseLocation
        
        var screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                screenFrame = screen.visibleFrame
                break
            }
        }
        
        var overlayOrigin = NSPoint(
            x: mouseLocation.x - frame.width / 2,
            y: mouseLocation.y + 20
        )
        
        if overlayOrigin.x < screenFrame.minX {
            overlayOrigin.x = screenFrame.minX + 10
        } else if overlayOrigin.x + frame.width > screenFrame.maxX {
            overlayOrigin.x = screenFrame.maxX - frame.width - 10
        }
        
        if overlayOrigin.y + frame.height > screenFrame.maxY {
            overlayOrigin.y = mouseLocation.y - frame.height - 20
        }
        
        setFrameOrigin(overlayOrigin)
        
        alphaValue = 0
        orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }
    
    func hide(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.waveformView.reset()
            self?.state = .recording
            self?.iconView.contentTintColor = .white
            completion?()
        })
    }
    
    func updateAudioLevel(_ level: Float) {
        waveformView.updateLevel(level)
    }
    
    func setState(_ newState: State) {
        state = newState
    }
}
