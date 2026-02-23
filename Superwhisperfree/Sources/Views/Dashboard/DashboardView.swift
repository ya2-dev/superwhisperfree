import Cocoa

final class DashboardView: NSView {
    
    private var minutesSavedLabel: NSTextField!
    private var wordsLabel: NSTextField!
    private var typingWPMLabel: NSTextField!
    private var speakingWPMLabel: NSTextField!
    private var chartView: LineChartView!
    private var recentActivityList: RecentActivityListView!
    
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
        
        let chartTitleLabel = NSTextField(labelWithString: "Words Over Time")
        chartTitleLabel.font = DesignTokens.Typography.heading(size: 16)
        chartTitleLabel.textColor = NSColor.swText
        
        chartView = LineChartView()
        chartView.translatesAutoresizingMaskIntoConstraints = false
        
        let activityTitleLabel = NSTextField(labelWithString: "Recent Transcriptions")
        activityTitleLabel.font = DesignTokens.Typography.heading(size: 16)
        activityTitleLabel.textColor = NSColor.swText
        
        recentActivityList = RecentActivityListView()
        recentActivityList.translatesAutoresizingMaskIntoConstraints = false
        
        let preferencesButton = createButton(title: "Preferences...") { [weak self] in
            self?.onPreferencesRequested?()
        }
        
        mainStack.addArrangedSubview(titleLabel)
        mainStack.addArrangedSubview(statsGrid)
        mainStack.addArrangedSubview(typingTestButton)
        mainStack.addArrangedSubview(chartTitleLabel)
        mainStack.addArrangedSubview(chartView)
        mainStack.addArrangedSubview(activityTitleLabel)
        mainStack.addArrangedSubview(recentActivityList)
        mainStack.addArrangedSubview(preferencesButton)
        
        mainStack.setCustomSpacing(DesignTokens.Spacing.xl, after: titleLabel)
        mainStack.setCustomSpacing(DesignTokens.Spacing.lg, after: statsGrid)
        mainStack.setCustomSpacing(DesignTokens.Spacing.xl, after: typingTestButton)
        mainStack.setCustomSpacing(DesignTokens.Spacing.md, after: chartTitleLabel)
        mainStack.setCustomSpacing(DesignTokens.Spacing.lg, after: chartView)
        mainStack.setCustomSpacing(DesignTokens.Spacing.md, after: activityTitleLabel)
        mainStack.setCustomSpacing(DesignTokens.Spacing.xl, after: recentActivityList)
        
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
            
            recentActivityList.heightAnchor.constraint(equalToConstant: 220),
            recentActivityList.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            recentActivityList.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),
            
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
        
        let typingWPM = analytics.typingWPM ?? 45
        typingWPMLabel.stringValue = "\(typingWPM)"
        
        let minutes = analytics.minutesSaved(benchmarkWPM: typingWPM)
        if minutes > 0 {
            minutesSavedLabel.stringValue = String(format: "%.1f", minutes)
        } else {
            minutesSavedLabel.stringValue = "0"
        }
        
        let words = analytics.totalWords
        wordsLabel.stringValue = formatNumber(words)
        
        speakingWPMLabel.stringValue = "\(analytics.speakingWPM)"
        
        let recentStats = analytics.recentStats(days: 30)
        chartView.dataPoints = recentStats.map { Double($0.words) }
        
        recentActivityList.updateTranscriptions(analytics.recentTranscriptions)
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

private class RecentActivityListView: NSView {
    
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var emptyLabel: NSTextField!
    private var transcriptions: [TranscriptionRecord] = []
    
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
        layer?.backgroundColor = NSColor.swSurface.cgColor
        layer?.cornerRadius = DesignTokens.CornerRadius.medium
        
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let clipView = NSClipView()
        clipView.documentView = stackView
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        
        emptyLabel = NSTextField(labelWithString: "No transcriptions yet. Start dictating!")
        emptyLabel.font = DesignTokens.Typography.body(size: 13)
        emptyLabel.textColor = NSColor.swTextSecondary
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(scrollView)
        addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func updateTranscriptions(_ records: [TranscriptionRecord]) {
        transcriptions = records
        
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let displayRecords = Array(records.prefix(10))
        emptyLabel.isHidden = !displayRecords.isEmpty
        scrollView.isHidden = displayRecords.isEmpty
        
        for record in displayRecords {
            let rowView = TranscriptionRowView(record: record)
            rowView.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(rowView)
            
            NSLayoutConstraint.activate([
                rowView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                rowView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor)
            ])
        }
    }
}

private class TranscriptionRowView: NSView {
    
    private let record: TranscriptionRecord
    private var isExpanded = false
    private var textLabel: NSTextField!
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    init(record: TranscriptionRecord) {
        self.record = record
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        wantsLayer = true
        
        let containerStack = NSStackView()
        containerStack.orientation = .vertical
        containerStack.alignment = .leading
        containerStack.spacing = DesignTokens.Spacing.xs
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.edgeInsets = NSEdgeInsets(
            top: DesignTokens.Spacing.sm,
            left: DesignTokens.Spacing.md,
            bottom: DesignTokens.Spacing.sm,
            right: DesignTokens.Spacing.md
        )
        
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = DesignTokens.Spacing.md
        topRow.translatesAutoresizingMaskIntoConstraints = false
        
        let truncatedText = truncateText(record.text, maxLength: 60)
        textLabel = NSTextField(labelWithString: truncatedText)
        textLabel.font = DesignTokens.Typography.body(size: 13)
        textLabel.textColor = NSColor.swText
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let statsLabel = NSTextField(labelWithString: "\(record.wordCount) words · \(record.wpm) WPM")
        statsLabel.font = DesignTokens.Typography.body(size: 11)
        statsLabel.textColor = NSColor.swTextSecondary
        statsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let timeLabel = NSTextField(labelWithString: Self.dateFormatter.string(from: record.timestamp))
        timeLabel.font = DesignTokens.Typography.body(size: 11)
        timeLabel.textColor = NSColor.swTextSecondary
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        topRow.addArrangedSubview(textLabel)
        topRow.addArrangedSubview(statsLabel)
        topRow.addArrangedSubview(timeLabel)
        
        containerStack.addArrangedSubview(topRow)
        
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerStack)
        addSubview(separator)
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: separator.topAnchor),
            
            topRow.leadingAnchor.constraint(equalTo: containerStack.leadingAnchor, constant: DesignTokens.Spacing.md),
            topRow.trailingAnchor.constraint(equalTo: containerStack.trailingAnchor, constant: -DesignTokens.Spacing.md),
            
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.md),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(clickGesture)
        
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    private func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }
    
    @objc private func handleClick() {
        isExpanded.toggle()
        if isExpanded {
            textLabel.stringValue = record.text
            textLabel.lineBreakMode = .byWordWrapping
            textLabel.maximumNumberOfLines = 0
        } else {
            textLabel.stringValue = truncateText(record.text, maxLength: 60)
            textLabel.lineBreakMode = .byTruncatingTail
            textLabel.maximumNumberOfLines = 1
        }
        needsLayout = true
        superview?.needsLayout = true
    }
    
    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.swSurface.blended(withFraction: 0.1, of: NSColor.white)?.cgColor
    }
    
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }
}
