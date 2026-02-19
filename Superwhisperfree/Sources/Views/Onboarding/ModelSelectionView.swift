import Cocoa

struct ModelInfo {
    let id: String
    let name: String
    let size: String
    let speed: String
    let speedIcons: Int
    let description: String
    let supportsMultilingual: Bool
    
    static let models: [ModelInfo] = [
        ModelInfo(id: "parakeet-v2", name: "Parakeet v2", size: "630 MB", speed: "Very Fast", speedIcons: 5, description: "Best for English - extremely fast and accurate", supportsMultilingual: false),
        ModelInfo(id: "whisper-tiny", name: "Whisper Tiny", size: "75 MB", speed: "Instant", speedIcons: 5, description: "Ultra-light, basic accuracy", supportsMultilingual: true),
        ModelInfo(id: "whisper-base", name: "Whisper Base", size: "150 MB", speed: "Fast", speedIcons: 4, description: "Good balance of speed and accuracy", supportsMultilingual: true),
        ModelInfo(id: "whisper-small", name: "Whisper Small", size: "500 MB", speed: "Medium", speedIcons: 3, description: "Higher accuracy, moderate speed", supportsMultilingual: true),
    ]
    
    static func filtered(multilingual: Bool) -> [ModelInfo] {
        if multilingual {
            return models.filter { $0.supportsMultilingual }
        }
        return models
    }
    
    static func recommendedId(multilingual: Bool) -> String {
        return multilingual ? "whisper-base" : "parakeet-v2"
    }
}

final class ModelSelectionView: NSView {
    
    var onComplete: (() -> Void)?
    
    private var isMultilingual: Bool = false {
        didSet {
            updateModelsDisplay()
        }
    }
    private var selectedModelId: String = "parakeet-v2"
    private var modelCards: [String: OnboardingModelCardView] = [:]
    
    private let languageSegment = NSSegmentedControl()
    private let modelsStackView = NSStackView()
    private let downloadButton = NSButton()
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
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = DesignTokens.Spacing.md
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Choose Your Model")
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = NSColor.swText
        titleLabel.alignment = .center
        
        let subtitleLabel = NSTextField(wrappingLabelWithString: "Select a transcription model to download. You can change this later in Preferences.")
        subtitleLabel.font = DesignTokens.Typography.body(size: 14)
        subtitleLabel.textColor = NSColor.swTextSecondary
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2
        
        setupLanguageSegment()
        let modelsContainer = createModelsContainer()
        
        setupDownloadButton()
        setupProgressBar()
        setupStatusLabel()
        setupErrorLabel()
        
        let progressStack = NSStackView()
        progressStack.orientation = .vertical
        progressStack.alignment = .centerX
        progressStack.spacing = DesignTokens.Spacing.sm
        progressStack.addArrangedSubview(progressBar)
        progressStack.addArrangedSubview(statusLabel)
        progressStack.addArrangedSubview(errorLabel)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(languageSegment)
        stackView.addArrangedSubview(modelsContainer)
        stackView.addArrangedSubview(downloadButton)
        stackView.addArrangedSubview(progressStack)
        
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: subtitleLabel)
        stackView.setCustomSpacing(DesignTokens.Spacing.md, after: languageSegment)
        stackView.setCustomSpacing(DesignTokens.Spacing.lg, after: modelsContainer)
        stackView.setCustomSpacing(DesignTokens.Spacing.md, after: downloadButton)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            modelsContainer.widthAnchor.constraint(equalToConstant: 480),
            downloadButton.widthAnchor.constraint(equalToConstant: 180),
            downloadButton.heightAnchor.constraint(equalToConstant: 40),
            progressBar.widthAnchor.constraint(equalToConstant: 300)
        ])
        
        updateModelsDisplay()
    }
    
    private func setupLanguageSegment() {
        languageSegment.segmentCount = 2
        languageSegment.setLabel("English Only", forSegment: 0)
        languageSegment.setLabel("Multilingual", forSegment: 1)
        languageSegment.selectedSegment = 0
        languageSegment.segmentStyle = .rounded
        languageSegment.target = self
        languageSegment.action = #selector(languageChanged(_:))
    }
    
    @objc private func languageChanged(_ sender: NSSegmentedControl) {
        isMultilingual = sender.selectedSegment == 1
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
            let isRecommended = model.id == recommendedId
            let card = OnboardingModelCardView(model: model, isRecommended: isRecommended)
            card.isSelected = model.id == selectedModelId
            card.onSelect = { [weak self] in
                self?.selectModel(model.id)
            }
            modelCards[model.id] = card
            modelsStackView.addArrangedSubview(card)
            
            card.translatesAutoresizingMaskIntoConstraints = false
            card.widthAnchor.constraint(equalTo: modelsStackView.widthAnchor).isActive = true
        }
    }
    
    private func selectModel(_ modelId: String) {
        selectedModelId = modelId
        for (id, card) in modelCards {
            card.isSelected = id == modelId
        }
        errorLabel.isHidden = true
    }
    
    private func createModelsContainer() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.swSurface.cgColor
        container.layer?.cornerRadius = DesignTokens.CornerRadius.large
        
        modelsStackView.orientation = .vertical
        modelsStackView.alignment = .leading
        modelsStackView.spacing = DesignTokens.Spacing.sm
        modelsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(modelsStackView)
        
        NSLayoutConstraint.activate([
            modelsStackView.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.md),
            modelsStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.md),
            modelsStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.md),
            modelsStackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.Spacing.md)
        ])
        
        return container
    }
    
    private func setupDownloadButton() {
        downloadButton.title = "Download & Continue"
        downloadButton.bezelStyle = .rounded
        downloadButton.isBordered = true
        downloadButton.font = DesignTokens.Typography.body(size: 14)
        downloadButton.target = self
        downloadButton.action = #selector(downloadClicked)
        downloadButton.wantsLayer = true
        downloadButton.layer?.cornerRadius = DesignTokens.CornerRadius.medium
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
    
    @objc private func downloadClicked() {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadButton.isEnabled = false
        progressBar.isHidden = false
        progressBar.doubleValue = 0
        statusLabel.isHidden = false
        statusLabel.textColor = NSColor.swTextSecondary
        statusLabel.stringValue = "Downloading model..."
        errorLabel.isHidden = true
        
        for card in modelCards.values {
            card.isEnabled = false
        }
        languageSegment.isEnabled = false
        
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
        
        for card in modelCards.values {
            card.isEnabled = true
        }
        languageSegment.isEnabled = true
    }
    
    private func resetUIState() {
        isDownloading = false
        downloadButton.isEnabled = true
        progressBar.isHidden = true
        progressBar.isIndeterminate = false
        progressBar.stopAnimation(nil)
        statusLabel.isHidden = true
        errorLabel.isHidden = true
        
        for card in modelCards.values {
            card.isEnabled = true
        }
        languageSegment.isEnabled = true
    }
}

// MARK: - Onboarding Model Card View

final class OnboardingModelCardView: NSView {
    
    var onSelect: (() -> Void)?
    
    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    var isEnabled: Bool = true {
        didSet {
            alphaValue = isEnabled ? 1.0 : 0.5
        }
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
        layer?.borderWidth = 2
        updateAppearance()
        
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 4
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = DesignTokens.Spacing.sm
        
        let nameLabel = NSTextField(labelWithString: model.name)
        nameLabel.font = DesignTokens.Typography.heading(size: 14)
        nameLabel.textColor = NSColor.swText
        
        topRow.addArrangedSubview(nameLabel)
        
        if isRecommended {
            let badge = createBadge(text: "Recommended", backgroundColor: NSColor.swSuccess.withAlphaComponent(0.2), textColor: NSColor.swSuccess)
            topRow.addArrangedSubview(badge)
        }
        
        let sizeBadge = createBadge(text: model.size, backgroundColor: NSColor.swSurfaceHover, textColor: NSColor.swTextSecondary)
        topRow.addArrangedSubview(sizeBadge)
        
        let speedStack = NSStackView()
        speedStack.orientation = .horizontal
        speedStack.alignment = .centerY
        speedStack.spacing = 2
        
        let speedIcons = String(repeating: "⚡", count: model.speedIcons)
        let speedIconLabel = NSTextField(labelWithString: speedIcons)
        speedIconLabel.font = DesignTokens.Typography.body(size: 11)
        speedIconLabel.textColor = NSColor.swAccent
        
        let speedTextLabel = NSTextField(labelWithString: model.speed)
        speedTextLabel.font = DesignTokens.Typography.body(size: 12)
        speedTextLabel.textColor = NSColor.swTextSecondary
        
        speedStack.addArrangedSubview(speedIconLabel)
        speedStack.addArrangedSubview(speedTextLabel)
        topRow.addArrangedSubview(speedStack)
        
        let descriptionLabel = NSTextField(labelWithString: model.description)
        descriptionLabel.font = DesignTokens.Typography.body(size: 12)
        descriptionLabel.textColor = NSColor.swTextSecondary
        
        contentStack.addArrangedSubview(topRow)
        contentStack.addArrangedSubview(descriptionLabel)
        
        addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.md),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.md),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.md)
        ])
        
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(cardClicked))
        addGestureRecognizer(clickGesture)
    }
    
    private func updateAppearance() {
        if isSelected {
            layer?.borderColor = NSColor.swAccent.cgColor
            layer?.backgroundColor = NSColor.swAccent.withAlphaComponent(0.1).cgColor
        } else {
            layer?.borderColor = NSColor.clear.cgColor
            layer?.backgroundColor = NSColor.swSurfaceHover.cgColor
        }
    }
    
    @objc private func cardClicked() {
        guard isEnabled else { return }
        onSelect?()
    }
    
    private func createBadge(text: String, backgroundColor: NSColor, textColor: NSColor) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = backgroundColor.cgColor
        container.layer?.cornerRadius = DesignTokens.CornerRadius.small
        
        let label = NSTextField(labelWithString: text)
        label.font = DesignTokens.Typography.body(size: 11)
        label.textColor = textColor
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
