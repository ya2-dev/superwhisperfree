import Cocoa

protocol ModelCardViewDelegate: AnyObject {
    func modelCardDidSelect(_ card: ModelCardView)
    func modelCardDidRequestDownload(_ card: ModelCardView)
}

struct ModelCardData {
    let id: String
    let name: String
    let exactModelName: String
    let size: String
    let ramUsageMB: Int
    let description: String
    let isRecommended: Bool
    let isMultilingual: Bool
    let exceedsRAM: Bool
    var isDownloaded: Bool
}

final class ModelCardView: NSView {
    weak var delegate: ModelCardViewDelegate?
    let modelData: ModelCardData
    
    var isSelected: Bool = false {
        didSet { updateAppearance() }
    }
    
    private var isHovered: Bool = false {
        didSet { updateAppearance() }
    }
    
    private let containerView = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let exactNameLabel = NSTextField(labelWithString: "")
    private let sizeLabel = NSTextField(labelWithString: "")
    private let ramLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let downloadButton = NSButton()
    private let recommendedBadge = NSTextField(labelWithString: "Recommended")
    private let multilingualBadge = NSTextField(labelWithString: "Multilingual")
    private let ramWarningLabel = NSTextField(labelWithString: "")
    
    private var trackingArea: NSTrackingArea?
    
    init(modelData: ModelCardData) {
        self.modelData = modelData
        super.init(frame: .zero)
        setupViews()
        updateAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        wantsLayer = true
        
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        nameLabel.font = DesignTokens.Typography.heading(size: 16)
        nameLabel.textColor = .swText
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(nameLabel)
        nameLabel.stringValue = modelData.name
        
        exactNameLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        exactNameLabel.textColor = .swTextSecondary
        exactNameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(exactNameLabel)
        exactNameLabel.stringValue = modelData.exactModelName
        
        sizeLabel.font = DesignTokens.Typography.body(size: 12)
        sizeLabel.textColor = .swTextSecondary
        sizeLabel.wantsLayer = true
        sizeLabel.layer?.backgroundColor = NSColor.swSurfaceHover.cgColor
        sizeLabel.layer?.cornerRadius = DesignTokens.CornerRadius.small
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(sizeLabel)
        sizeLabel.stringValue = "  \(modelData.size)  "
        
        let ramText = modelData.ramUsageMB >= 1024
            ? String(format: "~%.1f GB RAM", Double(modelData.ramUsageMB) / 1024.0)
            : "~\(modelData.ramUsageMB) MB RAM"
        ramLabel.font = DesignTokens.Typography.body(size: 11)
        ramLabel.textColor = modelData.exceedsRAM ? .swError : .swTextSecondary
        ramLabel.wantsLayer = true
        ramLabel.layer?.backgroundColor = (modelData.exceedsRAM ? NSColor.swError : NSColor.swSurfaceHover).withAlphaComponent(0.15).cgColor
        ramLabel.layer?.cornerRadius = DesignTokens.CornerRadius.small
        ramLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(ramLabel)
        ramLabel.stringValue = "  \(ramText)  "
        
        ramWarningLabel.font = DesignTokens.Typography.body(size: 11)
        ramWarningLabel.textColor = .swError
        ramWarningLabel.translatesAutoresizingMaskIntoConstraints = false
        ramWarningLabel.isHidden = !modelData.exceedsRAM
        ramWarningLabel.stringValue = "May slow down other apps on this Mac"
        containerView.addSubview(ramWarningLabel)
        
        descriptionLabel.font = DesignTokens.Typography.body(size: 13)
        descriptionLabel.textColor = .swTextSecondary
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(descriptionLabel)
        descriptionLabel.stringValue = modelData.description
        
        recommendedBadge.font = DesignTokens.Typography.body(size: 11)
        recommendedBadge.textColor = .swSuccess
        recommendedBadge.isHidden = !modelData.isRecommended
        recommendedBadge.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(recommendedBadge)
        
        multilingualBadge.font = DesignTokens.Typography.body(size: 11)
        multilingualBadge.textColor = .swAccent
        multilingualBadge.stringValue = modelData.isMultilingual ? "Multilingual" : "English Only"
        multilingualBadge.isHidden = false
        multilingualBadge.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(multilingualBadge)
        
        statusLabel.font = DesignTokens.Typography.body(size: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        downloadButton.title = "Download"
        downloadButton.bezelStyle = .rounded
        downloadButton.font = DesignTokens.Typography.body(size: 12)
        downloadButton.target = self
        downloadButton.action = #selector(downloadButtonClicked)
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(downloadButton)
        
        updateDownloadStatus()
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: DesignTokens.Spacing.md),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DesignTokens.Spacing.md),
            
            sizeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            sizeLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: DesignTokens.Spacing.sm),
            
            ramLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            ramLabel.leadingAnchor.constraint(equalTo: sizeLabel.trailingAnchor, constant: DesignTokens.Spacing.xs),
            
            recommendedBadge.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            recommendedBadge.leadingAnchor.constraint(equalTo: ramLabel.trailingAnchor, constant: DesignTokens.Spacing.sm),
            
            multilingualBadge.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            multilingualBadge.leadingAnchor.constraint(equalTo: modelData.isRecommended ? recommendedBadge.trailingAnchor : ramLabel.trailingAnchor, constant: DesignTokens.Spacing.sm),
            
            exactNameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            exactNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DesignTokens.Spacing.md),
            
            descriptionLabel.topAnchor.constraint(equalTo: exactNameLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DesignTokens.Spacing.md),
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -DesignTokens.Spacing.md),
            
            ramWarningLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 2),
            ramWarningLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DesignTokens.Spacing.md),
            ramWarningLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -DesignTokens.Spacing.md),
            
            statusLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DesignTokens.Spacing.md),
            
            downloadButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            downloadButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DesignTokens.Spacing.md),
        ])
        
        heightAnchor.constraint(greaterThanOrEqualToConstant: 84).isActive = true
    }
    
    private func updateDownloadStatus() {
        if modelData.isDownloaded {
            statusLabel.stringValue = "✓ Downloaded"
            statusLabel.textColor = .swSuccess
            statusLabel.isHidden = false
            downloadButton.isHidden = true
        } else {
            statusLabel.stringValue = "Not downloaded"
            statusLabel.textColor = .swTextSecondary
            statusLabel.isHidden = true
            downloadButton.isHidden = false
        }
    }
    
    private func updateAppearance() {
        if isSelected {
            containerView.layer?.backgroundColor = NSColor.swSurfaceHover.cgColor
            containerView.layer?.borderColor = NSColor.swAccent.cgColor
            containerView.layer?.borderWidth = 2
        } else if isHovered {
            containerView.layer?.backgroundColor = NSColor.swSurfaceHover.cgColor
            containerView.layer?.borderColor = NSColor.swSurfaceHover.cgColor
            containerView.layer?.borderWidth = 1
        } else {
            containerView.layer?.backgroundColor = NSColor.swSurface.cgColor
            containerView.layer?.borderColor = NSColor.swSurface.cgColor
            containerView.layer?.borderWidth = 1
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    override func mouseDown(with event: NSEvent) {
        delegate?.modelCardDidSelect(self)
    }
    
    @objc private func downloadButtonClicked() {
        delegate?.modelCardDidRequestDownload(self)
    }
    
    func updateDownloadedState(_ isDownloaded: Bool) {
        var updatedData = modelData
        updatedData.isDownloaded = isDownloaded
        
        if isDownloaded {
            statusLabel.stringValue = "✓ Downloaded"
            statusLabel.textColor = .swSuccess
            statusLabel.isHidden = false
            downloadButton.isHidden = true
        } else {
            statusLabel.stringValue = "Not downloaded"
            statusLabel.textColor = .swTextSecondary
            statusLabel.isHidden = true
            downloadButton.isHidden = false
        }
    }
}
