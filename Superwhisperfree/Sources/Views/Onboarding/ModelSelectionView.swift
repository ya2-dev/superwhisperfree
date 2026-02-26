import Cocoa

struct ModelInfo {
    let id: String
    let name: String
    let exactModelName: String
    let size: String
    let speed: String
    let speedIcons: Int
    let description: String
    let ramUsageMB: Int
    let isEnglishOnly: Bool
    let isMultilingual: Bool
    let exceedsRAM: Bool
    
    static var englishModels: [ModelInfo] {
        let maxRAM = HardwareDetector.shared.maxRecommendedRAM
        return [
            ModelInfo(id: "parakeet", name: "Parakeet v2", exactModelName: "nemo-parakeet-tdt-0.6b-v2-int8", size: "460 MB", speed: "Very Fast", speedIcons: 5, description: "Fast and accurate - English only", ramUsageMB: 700, isEnglishOnly: true, isMultilingual: false, exceedsRAM: 700 > maxRAM),
            ModelInfo(id: "parakeet-v3", name: "Parakeet v3", exactModelName: "nemo-parakeet-tdt-0.6b-v3-int8", size: "465 MB", speed: "Very Fast", speedIcons: 5, description: "Best accuracy - 25 European languages", ramUsageMB: 750, isEnglishOnly: false, isMultilingual: true, exceedsRAM: 750 > maxRAM),
            ModelInfo(id: "whisper-tiny", name: "Whisper Tiny (EN)", exactModelName: "whisper-tiny.en", size: "75 MB", speed: "Instant", speedIcons: 5, description: "Ultra-light, basic accuracy", ramUsageMB: 390, isEnglishOnly: true, isMultilingual: false, exceedsRAM: 390 > maxRAM),
            ModelInfo(id: "whisper-base", name: "Whisper Base (EN)", exactModelName: "whisper-base.en", size: "150 MB", speed: "Fast", speedIcons: 4, description: "Good speed/accuracy balance", ramUsageMB: 500, isEnglishOnly: true, isMultilingual: false, exceedsRAM: 500 > maxRAM),
            ModelInfo(id: "whisper-small", name: "Whisper Small (EN)", exactModelName: "whisper-small.en", size: "500 MB", speed: "Medium", speedIcons: 3, description: "Higher accuracy, moderate speed", ramUsageMB: 1000, isEnglishOnly: true, isMultilingual: false, exceedsRAM: 1000 > maxRAM),
            ModelInfo(id: "whisper-distil-small", name: "Distil Small (EN)", exactModelName: "whisper-distil-small.en", size: "430 MB", speed: "Fast", speedIcons: 4, description: "Faster than Small, similar accuracy", ramUsageMB: 800, isEnglishOnly: true, isMultilingual: false, exceedsRAM: 800 > maxRAM),
            ModelInfo(id: "whisper-medium", name: "Whisper Medium (EN)", exactModelName: "whisper-medium.en", size: "1.8 GB", speed: "Slow", speedIcons: 2, description: "Very good accuracy, slower", ramUsageMB: 2500, isEnglishOnly: true, isMultilingual: false, exceedsRAM: 2500 > maxRAM),
            ModelInfo(id: "whisper-distil-medium", name: "Distil Medium (EN)", exactModelName: "whisper-distil-medium.en", size: "960 MB", speed: "Medium", speedIcons: 3, description: "Faster than Medium, similar accuracy", ramUsageMB: 1800, isEnglishOnly: true, isMultilingual: false, exceedsRAM: 1800 > maxRAM),
        ]
    }
    
    static var multilingualModels: [ModelInfo] {
        let maxRAM = HardwareDetector.shared.maxRecommendedRAM
        return [
            ModelInfo(id: "parakeet-v3", name: "Parakeet v3", exactModelName: "nemo-parakeet-tdt-0.6b-v3-int8", size: "465 MB", speed: "Very Fast", speedIcons: 5, description: "Best accuracy - 25 European languages", ramUsageMB: 750, isEnglishOnly: false, isMultilingual: true, exceedsRAM: 750 > maxRAM),
            ModelInfo(id: "whisper-tiny-multi", name: "Whisper Tiny (Multi)", exactModelName: "whisper-tiny", size: "110 MB", speed: "Instant", speedIcons: 5, description: "Ultra-light - 99 languages", ramUsageMB: 390, isEnglishOnly: false, isMultilingual: true, exceedsRAM: 390 > maxRAM),
            ModelInfo(id: "whisper-base-multi", name: "Whisper Base (Multi)", exactModelName: "whisper-base", size: "200 MB", speed: "Fast", speedIcons: 4, description: "Good speed/accuracy - 99 languages", ramUsageMB: 500, isEnglishOnly: false, isMultilingual: true, exceedsRAM: 500 > maxRAM),
            ModelInfo(id: "whisper-small-multi", name: "Whisper Small (Multi)", exactModelName: "whisper-small", size: "610 MB", speed: "Medium", speedIcons: 3, description: "Higher accuracy - 99 languages", ramUsageMB: 1000, isEnglishOnly: false, isMultilingual: true, exceedsRAM: 1000 > maxRAM),
            ModelInfo(id: "whisper-medium-multi", name: "Whisper Medium (Multi)", exactModelName: "whisper-medium", size: "1.8 GB", speed: "Slow", speedIcons: 2, description: "Very good accuracy - 99 languages", ramUsageMB: 2500, isEnglishOnly: false, isMultilingual: true, exceedsRAM: 2500 > maxRAM),
            ModelInfo(id: "whisper-turbo-multi", name: "Whisper Turbo (Multi)", exactModelName: "whisper-turbo", size: "540 MB", speed: "Fast", speedIcons: 4, description: "Optimized speed - 99 languages", ramUsageMB: 2500, isEnglishOnly: false, isMultilingual: true, exceedsRAM: 2500 > maxRAM),
            ModelInfo(id: "whisper-distil-large-v3.5-multi", name: "Distil Large v3.5 (Multi)", exactModelName: "whisper-distil-large-v3.5", size: "500 MB", speed: "Medium", speedIcons: 3, description: "Near Large-v3 quality, 6x faster - 99 languages", ramUsageMB: 2500, isEnglishOnly: false, isMultilingual: true, exceedsRAM: 2500 > maxRAM),
            ModelInfo(id: "whisper-large-v3-multi", name: "Whisper Large v3 (Multi)", exactModelName: "whisper-large-v3", size: "1 GB", speed: "Slow", speedIcons: 1, description: "Best accuracy available - 99 languages", ramUsageMB: 4500, isEnglishOnly: false, isMultilingual: true, exceedsRAM: 4500 > maxRAM),
        ]
    }
    
    static func filtered(multilingual: Bool) -> [ModelInfo] {
        return multilingual ? multilingualModels : englishModels
    }
    
    static func recommendedId(multilingual: Bool) -> String {
        return HardwareDetector.shared.recommendedModelId(multilingual: multilingual)
    }
}

// MARK: - Model Selection View

final class ModelSelectionView: NSView {
    
    var onComplete: (() -> Void)?
    
    private var isMultilingual: Bool = false {
        didSet { updateModelsDisplay() }
    }
    private var selectedModelId: String = HardwareDetector.shared.recommendedModelId(multilingual: false)
    private var modelCards: [String: OnboardingModelCardView] = [:]
    
    private let englishButton = NSButton()
    private let multilingualButton = NSButton()
    private let scrollView = NSScrollView()
    private let modelsStackView = NSStackView()
    private let downloadButton = SWButton(title: "Download & Continue", style: .primary)
    private let progressBar = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(labelWithString: "")
    
    private var isDownloading = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        
        let hPad: CGFloat = 40
        
        // --- Header ---
        let headerStack = NSStackView()
        headerStack.orientation = .vertical
        headerStack.alignment = .centerX
        headerStack.spacing = 10
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Choose Your Model")
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = NSColor.swText
        titleLabel.alignment = .center
        
        let hw = HardwareDetector.shared
        let subtitleLabel = NSTextField(labelWithString: "\(hw.ramGB) GB RAM detected")
        subtitleLabel.font = DesignTokens.Typography.body(size: 13)
        subtitleLabel.textColor = NSColor.swTextSecondary.withAlphaComponent(0.6)
        subtitleLabel.alignment = .center
        
        let toggleContainer = setupLanguageToggle()
        
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)
        headerStack.setCustomSpacing(20, after: subtitleLabel)
        headerStack.addArrangedSubview(toggleContainer)
        
        addSubview(headerStack)
        
        // --- Scrollable model list ---
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        
        modelsStackView.orientation = .vertical
        modelsStackView.alignment = .leading
        modelsStackView.spacing = 8
        modelsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let clipView = NSClipView()
        clipView.drawsBackground = false
        clipView.documentView = modelsStackView
        scrollView.contentView = clipView
        
        addSubview(scrollView)
        
        // --- Footer ---
        let footerStack = NSStackView()
        footerStack.orientation = .vertical
        footerStack.alignment = .centerX
        footerStack.spacing = DesignTokens.Spacing.sm
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        
        setupDownloadButton()
        setupProgressBar()
        setupStatusLabel()
        setupErrorLabel()
        
        footerStack.addArrangedSubview(downloadButton)
        footerStack.addArrangedSubview(progressBar)
        footerStack.addArrangedSubview(statusLabel)
        footerStack.addArrangedSubview(errorLabel)
        
        addSubview(footerStack)
        
        // --- Layout ---
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 44),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: hPad),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -hPad),
            
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 24),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: hPad),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -hPad),
            scrollView.bottomAnchor.constraint(equalTo: footerStack.topAnchor, constant: -20),
            
            modelsStackView.topAnchor.constraint(equalTo: clipView.topAnchor),
            modelsStackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            modelsStackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            
            footerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
            footerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: hPad),
            footerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -hPad),
            
            downloadButton.widthAnchor.constraint(equalToConstant: 200),
            downloadButton.heightAnchor.constraint(equalToConstant: 38),
            progressBar.widthAnchor.constraint(equalToConstant: 300)
        ])
        
        updateModelsDisplay()
    }
    
    private func setupLanguageToggle() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 0
        container.alignment = .centerY
        
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.swText.withAlphaComponent(0.15).cgColor
        container.layer?.backgroundColor = NSColor.swSurface.cgColor
        
        func styleButton(_ btn: NSButton, title: String) {
            btn.title = title
            btn.isBordered = false
            btn.bezelStyle = .inline
            btn.font = DesignTokens.Typography.body(size: 12)
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 6
            btn.target = self
            btn.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                btn.heightAnchor.constraint(equalToConstant: 30),
                btn.widthAnchor.constraint(equalToConstant: 110)
            ])
        }
        
        styleButton(englishButton, title: "English")
        englishButton.action = #selector(englishTapped)
        
        styleButton(multilingualButton, title: "Multilingual")
        multilingualButton.action = #selector(multilingualTapped)
        
        let pad = NSEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        container.edgeInsets = pad
        
        container.addArrangedSubview(englishButton)
        container.addArrangedSubview(multilingualButton)
        
        updateToggleAppearance()
        return container
    }
    
    private func updateToggleAppearance() {
        let active = NSColor.swText
        let activeBg = NSColor.swText.withAlphaComponent(0.12)
        let inactiveBg = NSColor.clear
        let inactiveText = NSColor.swTextSecondary.withAlphaComponent(0.5)
        
        if !isMultilingual {
            englishButton.contentTintColor = active
            englishButton.layer?.backgroundColor = activeBg.cgColor
            multilingualButton.contentTintColor = inactiveText
            multilingualButton.layer?.backgroundColor = inactiveBg.cgColor
        } else {
            multilingualButton.contentTintColor = active
            multilingualButton.layer?.backgroundColor = activeBg.cgColor
            englishButton.contentTintColor = inactiveText
            englishButton.layer?.backgroundColor = inactiveBg.cgColor
        }
    }
    
    @objc private func englishTapped() {
        isMultilingual = false
        updateToggleAppearance()
    }
    
    @objc private func multilingualTapped() {
        isMultilingual = true
        updateToggleAppearance()
    }
    
    private func updateModelsDisplay() {
        let filteredModels = ModelInfo.filtered(multilingual: isMultilingual)
        let recommendedId = ModelInfo.recommendedId(multilingual: isMultilingual)
        
        if !filteredModels.contains(where: { $0.id == selectedModelId }) {
            selectedModelId = recommendedId
        }
        
        for view in modelsStackView.arrangedSubviews {
            modelsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        modelCards.removeAll()
        
        for model in filteredModels {
            let isRec = model.id == recommendedId
            let card = OnboardingModelCardView(model: model, isRecommended: isRec)
            card.isSelected = model.id == selectedModelId
            card.onSelect = { [weak self] in
                self?.selectModel(model.id)
            }
            modelCards[model.id] = card
            modelsStackView.addArrangedSubview(card)
            
            card.translatesAutoresizingMaskIntoConstraints = false
            card.widthAnchor.constraint(equalTo: modelsStackView.widthAnchor).isActive = true
        }
        
        // Scroll recommended card into view
        if let recCard = modelCards[recommendedId] {
            DispatchQueue.main.async {
                recCard.scrollToVisible(recCard.bounds)
            }
        }
    }
    
    private func selectModel(_ modelId: String) {
        selectedModelId = modelId
        for (id, card) in modelCards {
            card.isSelected = id == modelId
        }
        errorLabel.isHidden = true
    }
    
    private func setupDownloadButton() {
        downloadButton.setAction { [weak self] in
            self?.downloadClicked()
        }
    }
    
    private func setupProgressBar() {
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        progressBar.isHidden = true
    }
    
    private func setupStatusLabel() {
        statusLabel.font = DesignTokens.Typography.body(size: 13)
        statusLabel.textColor = NSColor.swTextSecondary
        statusLabel.alignment = .center
        statusLabel.isHidden = true
    }
    
    private func setupErrorLabel() {
        errorLabel.font = DesignTokens.Typography.body(size: 13)
        errorLabel.textColor = NSColor.swError
        errorLabel.alignment = .center
        errorLabel.isHidden = true
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.maximumNumberOfLines = 3
        errorLabel.preferredMaxLayoutWidth = 400
    }
    
    private func downloadClicked() {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadButton.isEnabled = false
        progressBar.isHidden = false
        progressBar.doubleValue = 0
        statusLabel.isHidden = false
        statusLabel.textColor = NSColor.swTextSecondary
        statusLabel.stringValue = "Downloading model..."
        errorLabel.isHidden = true
        
        for card in modelCards.values { card.isEnabled = false }
        englishButton.isEnabled = false
        multilingualButton.isEnabled = false
        
        ModelDownloader.shared.download(
            modelId: selectedModelId,
            progress: { [weak self] progress, message in
                self?.progressBar.doubleValue = progress
                self?.statusLabel.stringValue = message
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                self.isDownloading = false
                
                switch result {
                case .success:
                    self.saveModelToSettings()
                    self.statusLabel.stringValue = "Download complete!"
                    self.statusLabel.textColor = NSColor.swSuccess
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.onComplete?()
                    }
                case .failure(let error):
                    self.showError(error.localizedDescription)
                }
            }
        )
    }
    
    private func showError(_ message: String) {
        downloadButton.isEnabled = true
        progressBar.isHidden = true
        statusLabel.isHidden = true
        errorLabel.isHidden = false
        errorLabel.stringValue = "Error: \(message)"
        isDownloading = false
        
        for card in modelCards.values { card.isEnabled = true }
        englishButton.isEnabled = true
        multilingualButton.isEnabled = true
    }
    
    private func saveModelToSettings() {
        var settings = SettingsManager.shared.settings
        
        if selectedModelId == "parakeet" {
            settings.modelType = "parakeet"
            settings.modelSize = "default"
            settings.languageMode = "english"
        } else if selectedModelId == "parakeet-v3" {
            settings.modelType = "parakeet-v3"
            settings.modelSize = "default"
            settings.languageMode = isMultilingual ? "multilingual" : "english"
        } else if selectedModelId.hasPrefix("whisper-") {
            settings.modelType = "whisper"
            var size = String(selectedModelId.dropFirst(8))
            if size.hasSuffix("-multi") {
                size = String(size.dropLast(6))
                settings.languageMode = "multilingual"
            } else {
                settings.languageMode = "english"
            }
            settings.modelSize = size
        }
        
        SettingsManager.shared.settings = settings
        SettingsManager.shared.save()
    }
    
    private func resetUIState() {
        isDownloading = false
        downloadButton.isEnabled = true
        progressBar.isHidden = true
        progressBar.isIndeterminate = false
        progressBar.stopAnimation(nil)
        statusLabel.isHidden = true
        errorLabel.isHidden = true
        
        for card in modelCards.values { card.isEnabled = true }
        englishButton.isEnabled = true
        multilingualButton.isEnabled = true
    }
}

// MARK: - Onboarding Model Card View

final class OnboardingModelCardView: NSView {
    
    var onSelect: (() -> Void)?
    
    var isSelected: Bool = false {
        didSet { updateAppearance() }
    }
    
    var isEnabled: Bool = true {
        didSet { alphaValue = isEnabled ? 1.0 : 0.5 }
    }
    
    private let model: ModelInfo
    private let isRecommended: Bool
    
    init(model: ModelInfo, isRecommended: Bool) {
        self.model = model
        self.isRecommended = isRecommended
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = DesignTokens.CornerRadius.medium
        layer?.borderWidth = isRecommended ? 1.5 : 1
        updateAppearance()
        
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 6
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Row 1: Name + Recommended badge
        let nameRow = NSStackView()
        nameRow.orientation = .horizontal
        nameRow.alignment = .centerY
        nameRow.spacing = DesignTokens.Spacing.sm
        
        let nameLabel = NSTextField(labelWithString: model.name)
        nameLabel.font = DesignTokens.Typography.heading(size: 13)
        nameLabel.textColor = NSColor.swText
        nameRow.addArrangedSubview(nameLabel)
        
        if isRecommended {
            let badge = makePill(text: "Recommended", bg: NSColor.swSuccess.withAlphaComponent(0.15), fg: NSColor.swSuccess)
            nameRow.addArrangedSubview(badge)
        }
        
        if model.exceedsRAM {
            let warn = makePill(text: "High RAM", bg: NSColor.swError.withAlphaComponent(0.12), fg: NSColor.swError)
            nameRow.addArrangedSubview(warn)
        }
        
        // Row 2: Stat pills
        let statsRow = NSStackView()
        statsRow.orientation = .horizontal
        statsRow.alignment = .centerY
        statsRow.spacing = 6
        
        let sizePill = makePill(text: model.size, bg: NSColor.swSurfaceHover, fg: NSColor.swTextSecondary)
        statsRow.addArrangedSubview(sizePill)
        
        let ramText = model.ramUsageMB >= 1024
            ? String(format: "%.1f GB", Double(model.ramUsageMB) / 1024.0)
            : "\(model.ramUsageMB) MB"
        let ramColor = model.exceedsRAM ? NSColor.swError : NSColor.swTextSecondary
        let ramBg = model.exceedsRAM ? NSColor.swError.withAlphaComponent(0.1) : NSColor.swSurfaceHover
        let ramPill = makePill(text: ramText + " RAM", bg: ramBg, fg: ramColor)
        statsRow.addArrangedSubview(ramPill)
        
        let speedText = String(repeating: "⚡", count: min(model.speedIcons, 5)) + " " + model.speed
        let speedPill = makePill(text: speedText, bg: NSColor.swSurfaceHover, fg: NSColor.swAccent.withAlphaComponent(0.8))
        statsRow.addArrangedSubview(speedPill)
        
        // Row 3: Description
        let descLabel = NSTextField(labelWithString: model.description)
        descLabel.font = DesignTokens.Typography.body(size: 11)
        descLabel.textColor = NSColor.swTextSecondary
        
        contentStack.addArrangedSubview(nameRow)
        contentStack.addArrangedSubview(statsRow)
        contentStack.addArrangedSubview(descLabel)
        
        addSubview(contentStack)
        
        let vPad: CGFloat = 10
        let hPad: CGFloat = 12
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: vPad),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: hPad),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -hPad),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -vPad)
        ])
        
        let click = NSClickGestureRecognizer(target: self, action: #selector(cardClicked))
        addGestureRecognizer(click)
    }
    
    private func updateAppearance() {
        if isSelected {
            layer?.borderColor = NSColor.swAccent.cgColor
            layer?.backgroundColor = NSColor.swAccent.withAlphaComponent(0.08).cgColor
        } else if isRecommended {
            layer?.borderColor = NSColor.swAccent.withAlphaComponent(0.25).cgColor
            layer?.backgroundColor = NSColor.swSurfaceHover.withAlphaComponent(0.6).cgColor
        } else {
            layer?.borderColor = NSColor.clear.cgColor
            layer?.backgroundColor = NSColor.swSurfaceHover.withAlphaComponent(0.4).cgColor
        }
    }
    
    @objc private func cardClicked() {
        guard isEnabled else { return }
        onSelect?()
    }
    
    private func makePill(text: String, bg: NSColor, fg: NSColor) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = bg.cgColor
        container.layer?.cornerRadius = 4
        
        let label = NSTextField(labelWithString: text)
        label.font = DesignTokens.Typography.body(size: 10)
        label.textColor = fg
        label.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2)
        ])
        
        return container
    }
}
