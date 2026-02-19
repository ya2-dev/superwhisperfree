import Cocoa

final class DashboardView: NSView {
    
    private var minutesSavedLabel: NSTextField!
    private var wordsLabel: NSTextField!
    private var typingWPMLabel: NSTextField!
    private var speakingWPMLabel: NSTextField!
    private var chartView: LineChartView!
    
    var onTypingTestRequested: (() -> Void)?
    var onPreferencesRequested: (() -> Void)?
    
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
        layer?.backgroundColor = NSColor.swBackground.cgColor
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = DesignTokens.Spacing.lg
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Dashboard")
        titleLabel.font = DesignTokens.Typography.heading(size: 24)
        titleLabel.textColor = NSColor.swText
        
        let statsGrid = createStatsGrid()
        
        let typingTestButton = createButton(title: "Take Typing Test") { [weak self] in
            self?.onTypingTestRequested?()
        }
        
        let chartTitleLabel = NSTextField(labelWithString: "Recent Activity")
        chartTitleLabel.font = DesignTokens.Typography.heading(size: 16)
        chartTitleLabel.textColor = NSColor.swText
        
        chartView = LineChartView()
        chartView.translatesAutoresizingMaskIntoConstraints = false
        
        let preferencesButton = createButton(title: "Preferences...") { [weak self] in
            self?.onPreferencesRequested?()
        }
        
        mainStack.addArrangedSubview(titleLabel)
        mainStack.addArrangedSubview(statsGrid)
        mainStack.addArrangedSubview(typingTestButton)
        mainStack.addArrangedSubview(chartTitleLabel)
        mainStack.addArrangedSubview(chartView)
        mainStack.addArrangedSubview(preferencesButton)
        
        mainStack.setCustomSpacing(DesignTokens.Spacing.xl, after: titleLabel)
        mainStack.setCustomSpacing(DesignTokens.Spacing.lg, after: statsGrid)
        mainStack.setCustomSpacing(DesignTokens.Spacing.xl, after: typingTestButton)
        mainStack.setCustomSpacing(DesignTokens.Spacing.md, after: chartTitleLabel)
        mainStack.setCustomSpacing(DesignTokens.Spacing.xl, after: chartView)
        
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.xl),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.xl),
            
            statsGrid.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            statsGrid.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),
            
            chartView.heightAnchor.constraint(equalToConstant: 200),
            chartView.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),
            
            typingTestButton.heightAnchor.constraint(equalToConstant: 36),
            preferencesButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        refreshStats()
    }
    
    private func createStatsGrid() -> NSView {
        let gridStack = NSStackView()
        gridStack.orientation = .horizontal
        gridStack.distribution = .fillEqually
        gridStack.spacing = DesignTokens.Spacing.md
        gridStack.translatesAutoresizingMaskIntoConstraints = false
        
        let (minutesCard, minutesValueLabel) = createStatCard(title: "minutes saved")
        minutesSavedLabel = minutesValueLabel
        
        let (wordsCard, wordsValueLabel) = createStatCard(title: "words dictated")
        wordsLabel = wordsValueLabel
        
        let (typingCard, typingValueLabel) = createStatCard(title: "typing WPM")
        typingWPMLabel = typingValueLabel
        
        let (speakingCard, speakingValueLabel) = createStatCard(title: "speaking WPM")
        speakingWPMLabel = speakingValueLabel
        
        gridStack.addArrangedSubview(minutesCard)
        gridStack.addArrangedSubview(wordsCard)
        gridStack.addArrangedSubview(typingCard)
        gridStack.addArrangedSubview(speakingCard)
        
        return gridStack
    }
    
    private func createStatCard(title: String) -> (NSView, NSTextField) {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.swSurface.cgColor
        card.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = NSTextField(labelWithString: "—")
        valueLabel.font = DesignTokens.Typography.heading(size: 28)
        valueLabel.textColor = NSColor.swText
        valueLabel.alignment = .center
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = DesignTokens.Typography.body(size: 11)
        titleLabel.textColor = NSColor.swTextSecondary
        titleLabel.alignment = .center
        
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(titleLabel)
        
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 80),
            
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: DesignTokens.Spacing.sm),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -DesignTokens.Spacing.sm)
        ])
        
        return (card, valueLabel)
    }
    
    private func createButton(title: String, action: @escaping () -> Void) -> NSButton {
        let button = DashboardButton(title: title, action: action)
        return button
    }
    
    func refreshStats() {
        let analytics = AnalyticsManager.shared
        
        let minutes = analytics.minutesSaved()
        if minutes > 0 {
            minutesSavedLabel.stringValue = String(format: "%.1f", minutes)
        } else {
            minutesSavedLabel.stringValue = "0"
        }
        
        let words = analytics.totalWords
        wordsLabel.stringValue = formatNumber(words)
        
        if let typingWPM = analytics.typingWPM {
            typingWPMLabel.stringValue = "\(typingWPM)"
        } else {
            typingWPMLabel.stringValue = "—"
        }
        
        speakingWPMLabel.stringValue = "\(analytics.speakingWPM)"
        
        let recentStats = analytics.recentStats(days: 30)
        chartView.dataPoints = recentStats.map { Double($0.words) }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            let thousands = Double(number) / 1000.0
            return String(format: "%.1fk", thousands)
        }
        return "\(number)"
    }
}

private class DashboardButton: NSButton {
    
    private var actionHandler: (() -> Void)?
    
    convenience init(title: String, action: @escaping () -> Void) {
        self.init(frame: .zero)
        self.title = title
        self.actionHandler = action
        setupButton()
    }
    
    private func setupButton() {
        bezelStyle = .rounded
        isBordered = true
        font = DesignTokens.Typography.body(size: 13)
        target = self
        self.action = #selector(buttonClicked)
        
        wantsLayer = true
        layer?.cornerRadius = DesignTokens.CornerRadius.medium
    }
    
    @objc private func buttonClicked() {
        actionHandler?()
    }
}
