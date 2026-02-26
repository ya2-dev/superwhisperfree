import Cocoa

final class ModelsPreferencesView: NSView {
    
    private let headerLabel = NSTextField(labelWithString: "Models")
    private let refreshButton = NSButton()
    private let scrollView = NSScrollView()
    private let contentView = NSStackView()
    
    private var modelCards: [ModelCardView] = []
    private var selectedModelId: String?
    
    private static var availableModels: [ModelCardData] {
        let hw = HardwareDetector.shared
        let recEN = hw.recommendedModelId(multilingual: false)
        let recMulti = hw.recommendedModelId(multilingual: true)
        let maxRAM = hw.maxRecommendedRAM
        
        struct M {
            let id: String; let name: String; let exact: String; let size: String
            let ramMB: Int; let desc: String; let multi: Bool
        }
        
        let models: [M] = [
            M(id: "parakeet", name: "Parakeet v2", exact: "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8", size: "460 MB", ramMB: 700, desc: "Fast and accurate - English only", multi: false),
            M(id: "parakeet-v3", name: "Parakeet v3", exact: "sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8", size: "465 MB", ramMB: 750, desc: "Best accuracy - 25 European languages", multi: true),
            M(id: "whisper-tiny", name: "Whisper Tiny (EN)", exact: "sherpa-onnx-whisper-tiny.en", size: "75 MB", ramMB: 390, desc: "Ultra-light, basic accuracy", multi: false),
            M(id: "whisper-tiny-multi", name: "Whisper Tiny (Multi)", exact: "sherpa-onnx-whisper-tiny", size: "110 MB", ramMB: 390, desc: "Ultra-light - 99 languages", multi: true),
            M(id: "whisper-base", name: "Whisper Base (EN)", exact: "sherpa-onnx-whisper-base.en", size: "150 MB", ramMB: 500, desc: "Good speed/accuracy balance", multi: false),
            M(id: "whisper-base-multi", name: "Whisper Base (Multi)", exact: "sherpa-onnx-whisper-base", size: "200 MB", ramMB: 500, desc: "Good speed/accuracy - 99 languages", multi: true),
            M(id: "whisper-small", name: "Whisper Small (EN)", exact: "sherpa-onnx-whisper-small.en", size: "500 MB", ramMB: 1000, desc: "Higher accuracy, moderate speed", multi: false),
            M(id: "whisper-small-multi", name: "Whisper Small (Multi)", exact: "sherpa-onnx-whisper-small", size: "610 MB", ramMB: 1000, desc: "Higher accuracy - 99 languages", multi: true),
            M(id: "whisper-medium", name: "Whisper Medium (EN)", exact: "sherpa-onnx-whisper-medium.en", size: "1.8 GB", ramMB: 2500, desc: "Very good accuracy, slower", multi: false),
            M(id: "whisper-medium-multi", name: "Whisper Medium (Multi)", exact: "sherpa-onnx-whisper-medium", size: "1.8 GB", ramMB: 2500, desc: "Very good accuracy - 99 languages", multi: true),
            M(id: "whisper-distil-small", name: "Distil Small (EN)", exact: "sherpa-onnx-whisper-distil-small.en", size: "430 MB", ramMB: 800, desc: "Faster than Small, similar accuracy", multi: false),
            M(id: "whisper-distil-medium", name: "Distil Medium (EN)", exact: "sherpa-onnx-whisper-distil-medium.en", size: "960 MB", ramMB: 1800, desc: "Faster than Medium, similar accuracy", multi: false),
            M(id: "whisper-turbo-multi", name: "Whisper Turbo (Multi)", exact: "sherpa-onnx-whisper-turbo", size: "540 MB", ramMB: 2500, desc: "Optimized for speed - 99 languages", multi: true),
            M(id: "whisper-distil-large-v3.5-multi", name: "Distil Large v3.5 (Multi)", exact: "sherpa-onnx-whisper-distil-large-v3.5", size: "500 MB", ramMB: 2500, desc: "Near Large-v3 quality, 6x faster - 99 languages", multi: true),
            M(id: "whisper-large-v3-multi", name: "Whisper Large v3 (Multi)", exact: "sherpa-onnx-whisper-large-v3", size: "1 GB", ramMB: 4500, desc: "Best accuracy available - 99 languages", multi: true),
        ]
        
        return models.map { m in
            ModelCardData(
                id: m.id,
                name: m.name,
                exactModelName: m.exact,
                size: m.size,
                ramUsageMB: m.ramMB,
                description: m.desc,
                isRecommended: m.id == recEN || m.id == recMulti,
                isMultilingual: m.multi,
                exceedsRAM: m.ramMB > maxRAM,
                isDownloaded: ModelDownloader.isModelDownloaded(m.id)
            )
        }
    }
    
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
        
        if settings.modelType.lowercased() == "parakeet" {
            currentModelId = settings.modelSize == "v3" ? "parakeet-v3" : "parakeet"
        } else if settings.modelType.lowercased() == "parakeet-v3" {
            currentModelId = "parakeet-v3"
        } else {
            let isMultilingual = settings.languageMode == "multilingual"
            let suffix = isMultilingual ? "-multi" : ""
            currentModelId = "whisper-\(settings.modelSize)\(suffix)"
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
        let isMulti = modelId.hasSuffix("-multi")
        var settings = SettingsManager.shared.settings
        settings.modelType = modelType
        settings.modelSize = modelSize
        if modelType == "parakeet" {
            settings.languageMode = "english"
        } else if modelType == "parakeet-v3" || isMulti {
            settings.languageMode = "multilingual"
        } else {
            settings.languageMode = "english"
        }
        SettingsManager.shared.settings = settings
        SettingsManager.shared.save()
        NotificationCenter.default.post(name: .languageSettingsDidChange, object: nil)
    }
    
    private func parseModelId(_ modelId: String) -> (type: String, size: String) {
        if modelId == "parakeet" {
            return ("parakeet", "default")
        } else if modelId == "parakeet-v3" {
            return ("parakeet-v3", "default")
        } else if modelId.hasPrefix("whisper-") {
            var rest = String(modelId.dropFirst(8))
            if rest.hasSuffix("-multi") {
                rest = String(rest.dropLast(6))
            }
            return ("whisper", rest)
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
