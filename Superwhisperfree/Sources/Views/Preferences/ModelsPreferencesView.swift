import Cocoa

final class ModelsPreferencesView: NSView {
    
    private let headerLabel = NSTextField(labelWithString: "Models")
    private let refreshButton = NSButton()
    private let scrollView = NSScrollView()
    private let contentView = NSStackView()
    
    private var modelCards: [ModelCardView] = []
    private var selectedModelId: String?
    
    private static let availableModels: [ModelCardData] = [
        ModelCardData(
            id: "parakeet",
            name: "Parakeet v2",
            size: "630 MB",
            description: "Best for English - extremely fast and accurate",
            isRecommended: true,
            isMultilingual: false,
            isDownloaded: ModelDownloader.isModelDownloaded("parakeet")
        ),
        ModelCardData(
            id: "whisper-tiny",
            name: "Whisper Tiny",
            size: "75 MB",
            description: "Ultra-light, basic accuracy",
            isRecommended: false,
            isMultilingual: true,
            isDownloaded: ModelDownloader.isModelDownloaded("whisper-tiny")
        ),
        ModelCardData(
            id: "whisper-base",
            name: "Whisper Base",
            size: "150 MB",
            description: "Good balance of speed and accuracy",
            isRecommended: false,
            isMultilingual: true,
            isDownloaded: ModelDownloader.isModelDownloaded("whisper-base")
        ),
        ModelCardData(
            id: "whisper-small",
            name: "Whisper Small",
            size: "500 MB",
            description: "Higher accuracy, moderate speed",
            isRecommended: false,
            isMultilingual: true,
            isDownloaded: ModelDownloader.isModelDownloaded("whisper-small")
        )
    ]
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
        loadModelCards()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.swBackground.cgColor
        
        headerLabel.font = DesignTokens.Typography.heading(size: 20)
        headerLabel.textColor = .swText
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerLabel)
        
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        refreshButton.bezelStyle = .circular
        refreshButton.isBordered = false
        refreshButton.target = self
        refreshButton.action = #selector(refreshButtonClicked)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.contentTintColor = .swText
        addSubview(refreshButton)
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        
        contentView.orientation = .vertical
        contentView.alignment = .leading
        contentView.spacing = DesignTokens.Spacing.sm
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = contentView
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.lg),
            headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            
            refreshButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.lg),
            refreshButton.widthAnchor.constraint(equalToConstant: 24),
            refreshButton.heightAnchor.constraint(equalToConstant: 24),
            
            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: DesignTokens.Spacing.lg),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.lg),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.lg),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        ])
    }
    
    private func loadModelCards() {
        modelCards.forEach { $0.removeFromSuperview() }
        modelCards.removeAll()
        
        for modelData in Self.availableModels {
            let card = ModelCardView(modelData: modelData)
            card.delegate = self
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addArrangedSubview(card)
            modelCards.append(card)
            
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
        }
        
        loadCurrentSelection()
    }
    
    private func loadCurrentSelection() {
        let settings = SettingsManager.shared.settings
        let currentModelId: String
        
        if settings.modelType == "parakeet" {
            currentModelId = "parakeet"
        } else {
            currentModelId = "whisper-\(settings.modelSize)"
        }
        
        selectedModelId = currentModelId
        
        for card in modelCards {
            card.isSelected = (card.modelData.id == currentModelId)
        }
    }
    
    private func refreshDownloadStatus() {
        for card in modelCards {
            let isDownloaded = ModelDownloader.isModelDownloaded(card.modelData.id)
            card.updateDownloadedState(isDownloaded)
        }
    }
    
    @objc private func refreshButtonClicked() {
        refreshDownloadStatus()
    }
}

extension ModelsPreferencesView: ModelCardViewDelegate {
    func modelCardDidSelect(_ card: ModelCardView) {
        guard card.modelData.isDownloaded else {
            return
        }
        
        selectedModelId = card.modelData.id
        
        for existingCard in modelCards {
            existingCard.isSelected = (existingCard === card)
        }
        
        saveSelection(modelId: card.modelData.id)
    }
    
    func modelCardDidRequestDownload(_ card: ModelCardView) {
        ModelDownloader.shared.download(
            modelId: card.modelData.id,
            progress: { progress, status in
                print("Download progress: \(Int(progress * 100))% - \(status)")
            },
            completion: { [weak self, weak card] result in
                switch result {
                case .success:
                    card?.updateDownloadedState(true)
                    if let card = card {
                        self?.modelCardDidSelect(card)
                    }
                case .failure(let error):
                    self?.showDownloadError(error)
                }
            }
        )
    }
    
    private func saveSelection(modelId: String) {
        let (modelType, modelSize) = parseModelId(modelId)
        var settings = SettingsManager.shared.settings
        settings.modelType = modelType
        settings.modelSize = modelSize
        SettingsManager.shared.settings = settings
        SettingsManager.shared.save()
    }
    
    private func parseModelId(_ modelId: String) -> (type: String, size: String) {
        if modelId == "parakeet" {
            return ("parakeet", "default")
        } else if modelId.hasPrefix("whisper-") {
            let size = String(modelId.dropFirst(8))
            return ("whisper", size)
        }
        return ("parakeet", "default")
    }
    
    private func showDownloadError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Download Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
