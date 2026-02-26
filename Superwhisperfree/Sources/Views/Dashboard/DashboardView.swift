import Cocoa

final class DashboardView: NSView {
    
    private var heroValueLabel: NSTextField!
    private var heroSubtitleLabel: NSTextField!
    
    private var wordsValueLabel: NSTextField!
    private var sessionsValueLabel: NSTextField!
    private var wpmValueLabel: NSTextField!
    private var avgWordsValueLabel: NSTextField!
    
    private var chartView: LineChartView!
    private var recentActivityList: RecentActivityListView!
    
    private var periodButtons: [NSButton] = []
    private var selectedPeriod: StatPeriod = .week
    
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
    
    // MARK: - Layout

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.swBackground.cgColor
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = DesignTokens.Spacing.lg
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.edgeInsets = NSEdgeInsets(
            top: DesignTokens.Spacing.xl,
            left: DesignTokens.Spacing.xl,
            bottom: DesignTokens.Spacing.xl,
            right: DesignTokens.Spacing.xl
        )
        
        let headerRow = createHeaderRow()
        let heroCard = createHeroCard()
        let statsGrid = createStatsGrid()
        
        let chartSection = createSectionHeader("Words Over Time")
        chartView = LineChartView()
        chartView.translatesAutoresizingMaskIntoConstraints = false
        
        let activitySection = createSectionHeader("Recent Transcriptions")
        recentActivityList = RecentActivityListView()
        recentActivityList.translatesAutoresizingMaskIntoConstraints = false
        
        let footerRow = createFooterRow()
        
        contentStack.addArrangedSubview(headerRow)
        contentStack.addArrangedSubview(heroCard)
        contentStack.addArrangedSubview(statsGrid)
        contentStack.addArrangedSubview(chartSection)
        contentStack.addArrangedSubview(chartView)
        contentStack.addArrangedSubview(activitySection)
        contentStack.addArrangedSubview(recentActivityList)
        contentStack.addArrangedSubview(footerRow)
        
        contentStack.setCustomSpacing(DesignTokens.Spacing.xl, after: headerRow)
        contentStack.setCustomSpacing(DesignTokens.Spacing.md, after: heroCard)
        contentStack.setCustomSpacing(DesignTokens.Spacing.xl, after: statsGrid)
        contentStack.setCustomSpacing(DesignTokens.Spacing.sm, after: chartSection)
        contentStack.setCustomSpacing(DesignTokens.Spacing.xl, after: chartView)
        contentStack.setCustomSpacing(DesignTokens.Spacing.sm, after: activitySection)
        contentStack.setCustomSpacing(DesignTokens.Spacing.lg, after: recentActivityList)
        
        let clipView = NSClipView()
        clipView.documentView = contentStack
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        
        addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            
            headerRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: DesignTokens.Spacing.xl),
            headerRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            
            heroCard.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: DesignTokens.Spacing.xl),
            heroCard.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            
            statsGrid.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: DesignTokens.Spacing.xl),
            statsGrid.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            
            chartSection.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: DesignTokens.Spacing.xl),
            chartView.heightAnchor.constraint(equalToConstant: 200),
            chartView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: DesignTokens.Spacing.xl),
            chartView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            
            activitySection.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: DesignTokens.Spacing.xl),
            recentActivityList.heightAnchor.constraint(equalToConstant: 220),
            recentActivityList.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: DesignTokens.Spacing.xl),
            recentActivityList.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            
            footerRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: DesignTokens.Spacing.xl),
            footerRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -DesignTokens.Spacing.xl)
        ])
        
        refreshStats()
    }
    
    // MARK: - Header (title + period selector)
    
    private func createHeaderRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = DesignTokens.Spacing.md
        row.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Dashboard")
        titleLabel.font = DesignTokens.Typography.heading(size: 22)
        titleLabel.textColor = NSColor.swText
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        let periodStack = NSStackView()
        periodStack.orientation = .horizontal
        periodStack.spacing = 2
        periodStack.translatesAutoresizingMaskIntoConstraints = false
        
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.swSurface.cgColor
        container.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        container.translatesAutoresizingMaskIntoConstraints = false
        
        for period in StatPeriod.allCases {
            let btn = NSButton(title: period.rawValue, target: self, action: #selector(periodTapped(_:)))
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.font = DesignTokens.Typography.body(size: 11)
            btn.tag = StatPeriod.allCases.firstIndex(of: period)!
            btn.wantsLayer = true
            btn.layer?.cornerRadius = DesignTokens.CornerRadius.small
            btn.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                btn.heightAnchor.constraint(equalToConstant: 26),
                btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])
            
            periodButtons.append(btn)
            periodStack.addArrangedSubview(btn)
        }
        
        container.addSubview(periodStack)
        NSLayoutConstraint.activate([
            periodStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            periodStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            periodStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            periodStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2)
        ])
        
        updatePeriodButtons()
        
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(NSView()) // spacer
        row.addArrangedSubview(container)
        
        return row
    }
    
    // MARK: - Hero stat (time saved)
    
    private func createHeroCard() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.swSurface.cgColor
        card.layer?.cornerRadius = DesignTokens.CornerRadius.large
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        heroValueLabel = NSTextField(labelWithString: "0")
        heroValueLabel.font = DesignTokens.Typography.heading(size: 40)
        heroValueLabel.textColor = NSColor.swText
        heroValueLabel.alignment = .center
        
        heroSubtitleLabel = NSTextField(labelWithString: "minutes saved")
        heroSubtitleLabel.font = DesignTokens.Typography.body(size: 12)
        heroSubtitleLabel.textColor = NSColor.swTextSecondary
        heroSubtitleLabel.alignment = .center
        
        stack.addArrangedSubview(heroValueLabel)
        stack.addArrangedSubview(heroSubtitleLabel)
        
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 100),
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        
        return card
    }
    
    // MARK: - 2x2 stats grid
    
    private func createStatsGrid() -> NSView {
        let outer = NSStackView()
        outer.orientation = .vertical
        outer.spacing = DesignTokens.Spacing.sm
        outer.translatesAutoresizingMaskIntoConstraints = false
        
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.distribution = .fillEqually
        topRow.spacing = DesignTokens.Spacing.sm
        
        let bottomRow = NSStackView()
        bottomRow.orientation = .horizontal
        bottomRow.distribution = .fillEqually
        bottomRow.spacing = DesignTokens.Spacing.sm
        
        let (wordsCard, wv) = createMiniStat(title: "words dictated")
        wordsValueLabel = wv
        let (sessionsCard, sv) = createMiniStat(title: "sessions")
        sessionsValueLabel = sv
        let (wpmCard, wpv) = createMiniStat(title: "avg speaking WPM")
        wpmValueLabel = wpv
        let (avgCard, av) = createMiniStat(title: "avg words / session")
        avgWordsValueLabel = av
        
        topRow.addArrangedSubview(wordsCard)
        topRow.addArrangedSubview(sessionsCard)
        bottomRow.addArrangedSubview(wpmCard)
        bottomRow.addArrangedSubview(avgCard)
        
        outer.addArrangedSubview(topRow)
        outer.addArrangedSubview(bottomRow)
        
        return outer
    }
    
    private func createMiniStat(title: String) -> (NSView, NSTextField) {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.swSurface.cgColor
        card.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let valLabel = NSTextField(labelWithString: "—")
        valLabel.font = DesignTokens.Typography.heading(size: 22)
        valLabel.textColor = NSColor.swText
        valLabel.alignment = .center
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = DesignTokens.Typography.body(size: 10)
        titleLabel.textColor = NSColor.swTextSecondary
        titleLabel.alignment = .center
        
        stack.addArrangedSubview(valLabel)
        stack.addArrangedSubview(titleLabel)
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 68),
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: DesignTokens.Spacing.sm),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -DesignTokens.Spacing.sm)
        ])
        
        return (card, valLabel)
    }
    
    // MARK: - Section header
    
    private func createSectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = DesignTokens.Typography.heading(size: 14)
        label.textColor = NSColor.swTextSecondary
        return label
    }
    
    // MARK: - Footer (typing test + prefs)
    
    private func createFooterRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.distribution = .fill
        row.spacing = DesignTokens.Spacing.sm
        row.translatesAutoresizingMaskIntoConstraints = false
        
        let typingBtn = DashboardButton(title: "Typing Test") { [weak self] in
            self?.onTypingTestRequested?()
        }
        typingBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([typingBtn.heightAnchor.constraint(equalToConstant: 32)])
        
        let prefsBtn = DashboardButton(title: "Preferences...") { [weak self] in
            self?.onPreferencesRequested?()
        }
        prefsBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([prefsBtn.heightAnchor.constraint(equalToConstant: 32)])
        
        row.addArrangedSubview(typingBtn)
        row.addArrangedSubview(NSView()) // spacer
        row.addArrangedSubview(prefsBtn)
        
        return row
    }
    
    // MARK: - Period selector
    
    @objc private func periodTapped(_ sender: NSButton) {
        selectedPeriod = StatPeriod.allCases[sender.tag]
        updatePeriodButtons()
        refreshStats()
    }
    
    private func updatePeriodButtons() {
        for (i, btn) in periodButtons.enumerated() {
            let isSelected = StatPeriod.allCases[i] == selectedPeriod
            btn.layer?.backgroundColor = isSelected ? NSColor.swText.cgColor : NSColor.clear.cgColor
            btn.contentTintColor = isSelected ? NSColor.swBackground : NSColor.swTextSecondary
        }
    }
    
    // MARK: - Data binding
    
    func refreshStats() {
        let analytics = AnalyticsManager.shared
        let ps = analytics.stats(for: selectedPeriod)
        
        let minutes = ps.minutesSaved
        if minutes >= 60 {
            heroValueLabel.stringValue = String(format: "%.1f", minutes / 60)
            heroSubtitleLabel.stringValue = "hours saved"
        } else {
            heroValueLabel.stringValue = minutes >= 1 ? String(format: "%.1f", minutes) : "0"
            heroSubtitleLabel.stringValue = "minutes saved"
        }
        
        wordsValueLabel.stringValue = formatNumber(ps.words)
        sessionsValueLabel.stringValue = "\(ps.sessions)"
        wpmValueLabel.stringValue = ps.speakingWPM > 0 ? "\(ps.speakingWPM)" : "—"
        avgWordsValueLabel.stringValue = ps.avgWordsPerSession > 0 ? "\(ps.avgWordsPerSession)" : "—"
        
        if selectedPeriod == .today {
            let hourly = analytics.todayHourlyStats()
            chartView.dataPoints = hourly.map { Double($0.words) }
            chartView.barLabels = hourly.map { entry in
                let h = entry.hour % 12 == 0 ? 12 : entry.hour % 12
                let ampm = entry.hour < 12 ? "a" : "p"
                return "\(h)\(ampm)"
            }
        } else {
            let dailyStats = ps.dailyStats
            chartView.dataPoints = dailyStats.map { Double($0.words) }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let labelFormatter = DateFormatter()
            labelFormatter.dateFormat = "d"
            
            chartView.barLabels = dailyStats.map { stat in
                if let date = dateFormatter.date(from: stat.date) {
                    return labelFormatter.string(from: date)
                }
                return ""
            }
        }
        
        recentActivityList.updateTranscriptions(analytics.recentTranscriptions)
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000.0)
        } else if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}

// MARK: - Helpers

private class DashboardButton: NSButton {
    
    private var actionHandler: (() -> Void)?
    
    convenience init(title: String, action: @escaping () -> Void) {
        self.init(frame: .zero)
        self.title = title
        self.actionHandler = action
        setupButton()
    }
    
    private func setupButton() {
        bezelStyle = .inline
        isBordered = false
        font = DesignTokens.Typography.body(size: 12)
        contentTintColor = NSColor.swTextSecondary
        target = self
        self.action = #selector(buttonClicked)
        
        wantsLayer = true
        layer?.cornerRadius = DesignTokens.CornerRadius.small
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.swBorder.cgColor
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
        if text.count <= maxLength { return text }
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
