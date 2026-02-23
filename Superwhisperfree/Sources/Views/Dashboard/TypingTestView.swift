import Cocoa

final class TypingTestWindowController: NSWindowController {
    
    var onComplete: ((Int) -> Void)?
    
    private var typingTestView: TypingTestView!
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Typing Test"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor.swBackground
        
        self.init(window: window)
        
        typingTestView = TypingTestView()
        typingTestView.translatesAutoresizingMaskIntoConstraints = false
        typingTestView.onComplete = { [weak self] wpm in
            self?.onComplete?(wpm)
        }
        
        guard let contentView = window.contentView else { return }
        contentView.addSubview(typingTestView)
        
        NSLayoutConstraint.activate([
            typingTestView.topAnchor.constraint(equalTo: contentView.topAnchor),
            typingTestView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            typingTestView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            typingTestView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}

final class TypingTestView: NSView, NSTextViewDelegate {
    
    private let sampleTexts = [
        "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs.",
        "How vexingly quick daft zebras jump! The five boxing wizards jump quickly at dawn.",
        "Sphinx of black quartz, judge my vow. Two driven jocks help fax my big quiz.",
        "The job requires extra pluck and zeal from every young wage earner. Quick zephyrs blow, vexing daft Jim.",
        "We promptly judged antique ivory buckles for the next prize. Crazy Frederick bought many very exquisite opal jewels."
    ]
    
    private var sampleTextView: NSTextView!
    private var inputTextView: NSTextView!
    private var timerLabel: NSTextField!
    private var startButton: NSButton!
    private var doneButton: NSButton!
    private var resultLabel: NSTextField!
    private var instructionLabel: NSTextField!
    
    private var timer: Timer?
    private var secondsRemaining: Int = 60
    private var totalTestTime: Int = 60
    private var isTestRunning = false
    private var currentSampleText: String = ""
    private var sampleWords: [String] = []
    private var startTime: Date?
    
    var onComplete: ((Int) -> Void)?
    
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
        mainStack.alignment = .centerX
        mainStack.spacing = DesignTokens.Spacing.md
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Typing Speed Test")
        titleLabel.font = DesignTokens.Typography.heading(size: 20)
        titleLabel.textColor = NSColor.swText
        
        instructionLabel = NSTextField(labelWithString: "Type the text below as quickly and accurately as you can.")
        instructionLabel.font = DesignTokens.Typography.body(size: 13)
        instructionLabel.textColor = NSColor.swTextSecondary
        instructionLabel.alignment = .center
        
        timerLabel = NSTextField(labelWithString: "60")
        timerLabel.font = DesignTokens.Typography.heading(size: 48)
        timerLabel.textColor = NSColor.swText
        timerLabel.alignment = .center
        
        let sampleScrollView = createTextView(isEditable: false, placeholder: "")
        sampleTextView = sampleScrollView.documentView as? NSTextView
        sampleTextView.font = DesignTokens.Typography.body(size: 14)
        sampleTextView.textColor = NSColor.swTextSecondary
        currentSampleText = sampleTexts.randomElement() ?? sampleTexts[0]
        sampleTextView.string = currentSampleText
        
        let inputScrollView = createTextView(isEditable: true, placeholder: "Start typing here...")
        inputTextView = inputScrollView.documentView as? NSTextView
        inputTextView.font = DesignTokens.Typography.body(size: 14)
        inputTextView.isEditable = false
        inputTextView.delegate = self
        
        startButton = createActionButton(title: "Start") { [weak self] in
            self?.startTest()
        }
        
        doneButton = createActionButton(title: "Done") { [weak self] in
            self?.finishAndClose()
        }
        doneButton.isHidden = true
        
        resultLabel = NSTextField(labelWithString: "")
        resultLabel.font = DesignTokens.Typography.heading(size: 18)
        resultLabel.textColor = NSColor.swSuccess
        resultLabel.alignment = .center
        resultLabel.isHidden = true
        
        mainStack.addArrangedSubview(titleLabel)
        mainStack.addArrangedSubview(instructionLabel)
        mainStack.addArrangedSubview(timerLabel)
        mainStack.addArrangedSubview(sampleScrollView)
        mainStack.addArrangedSubview(inputScrollView)
        mainStack.addArrangedSubview(startButton)
        mainStack.addArrangedSubview(resultLabel)
        mainStack.addArrangedSubview(doneButton)
        
        mainStack.setCustomSpacing(DesignTokens.Spacing.sm, after: titleLabel)
        mainStack.setCustomSpacing(DesignTokens.Spacing.lg, after: instructionLabel)
        mainStack.setCustomSpacing(DesignTokens.Spacing.md, after: timerLabel)
        mainStack.setCustomSpacing(DesignTokens.Spacing.md, after: sampleScrollView)
        mainStack.setCustomSpacing(DesignTokens.Spacing.lg, after: inputScrollView)
        
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.xl),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -DesignTokens.Spacing.xl),
            
            sampleScrollView.heightAnchor.constraint(equalToConstant: 60),
            sampleScrollView.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            
            inputScrollView.heightAnchor.constraint(equalToConstant: 80),
            inputScrollView.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            
            startButton.widthAnchor.constraint(equalToConstant: 120),
            startButton.heightAnchor.constraint(equalToConstant: 36),
            
            doneButton.widthAnchor.constraint(equalToConstant: 120),
            doneButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    private func createTextView(isEditable: Bool, placeholder: String) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = DesignTokens.Typography.body(size: 14)
        textView.textColor = NSColor.swText
        textView.backgroundColor = NSColor.swSurface
        textView.insertionPointColor = NSColor.swAccent
        textView.textContainerInset = NSSize(width: DesignTokens.Spacing.sm, height: DesignTokens.Spacing.sm)
        
        textView.wantsLayer = true
        textView.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        
        scrollView.documentView = textView
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = DesignTokens.CornerRadius.medium
        scrollView.layer?.backgroundColor = NSColor.swSurface.cgColor
        
        return scrollView
    }
    
    private func createActionButton(title: String, action: @escaping () -> Void) -> NSButton {
        let button = TypingTestButton(title: title, action: action)
        return button
    }
    
    private func startTest() {
        isTestRunning = true
        secondsRemaining = 60
        totalTestTime = 60
        inputTextView.string = ""
        inputTextView.isEditable = true
        window?.makeFirstResponder(inputTextView)
        
        startButton.isHidden = true
        resultLabel.isHidden = true
        doneButton.isHidden = true
        
        currentSampleText = sampleTexts.randomElement() ?? sampleTexts[0]
        sampleWords = currentSampleText.components(separatedBy: " ")
        startTime = Date()
        
        updateSampleTextHighlighting()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        secondsRemaining -= 1
        timerLabel.stringValue = "\(secondsRemaining)"
        
        if secondsRemaining <= 0 {
            endTest(completedEarly: false)
        }
    }
    
    private func endTest(completedEarly: Bool = false) {
        timer?.invalidate()
        timer = nil
        isTestRunning = false
        inputTextView.isEditable = false
        
        let timeTaken: Int
        if completedEarly, let start = startTime {
            timeTaken = Int(Date().timeIntervalSince(start))
        } else {
            timeTaken = totalTestTime - secondsRemaining
        }
        
        let stats = calculateStats(timeTaken: timeTaken)
        
        AnalyticsManager.shared.setTypingWPM(stats.wpm)
        
        resultLabel.stringValue = """
        WPM: \(stats.wpm) | Accuracy: \(stats.accuracy)% | Time: \(timeTaken)s
        """
        resultLabel.isHidden = false
        doneButton.isHidden = false
        instructionLabel.stringValue = completedEarly 
            ? "Excellent! You completed the test early!" 
            : "Test complete! Your result has been saved."
        
        onComplete?(stats.wpm)
    }
    
    private func calculateStats(timeTaken: Int) -> (wpm: Int, accuracy: Int) {
        let typedWords = inputTextView.string.components(separatedBy: " ").filter { !$0.isEmpty }
        let totalTypedWords = typedWords.count
        
        var correctWords = 0
        for (index, typedWord) in typedWords.enumerated() {
            if index < sampleWords.count && typedWord == sampleWords[index] {
                correctWords += 1
            }
        }
        
        let effectiveTime = max(timeTaken, 1)
        let wpm = Int(Double(correctWords) / (Double(effectiveTime) / 60.0))
        
        let accuracy: Int
        if totalTypedWords > 0 {
            accuracy = Int((Double(correctWords) / Double(totalTypedWords)) * 100)
        } else {
            accuracy = 0
        }
        
        return (wpm, accuracy)
    }
    
    private func updateSampleTextHighlighting() {
        let typedText = inputTextView.string
        let typedWords = typedText.components(separatedBy: " ")
        
        let attributedString = NSMutableAttributedString()
        
        for (index, sampleWord) in sampleWords.enumerated() {
            let wordWithSpace = index < sampleWords.count - 1 ? sampleWord + " " : sampleWord
            
            let attributes: [NSAttributedString.Key: Any]
            
            if index < typedWords.count - 1 {
                if typedWords[index] == sampleWord {
                    attributes = [
                        .foregroundColor: NSColor.swSuccess,
                        .font: DesignTokens.Typography.body(size: 14)
                    ]
                } else {
                    attributes = [
                        .foregroundColor: NSColor.swError,
                        .font: DesignTokens.Typography.body(size: 14),
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: NSColor.swError
                    ]
                }
            } else if index == typedWords.count - 1 {
                attributes = [
                    .foregroundColor: NSColor.swAccent,
                    .font: DesignTokens.Typography.body(size: 14),
                    .backgroundColor: NSColor.swSurfaceHover
                ]
            } else {
                attributes = [
                    .foregroundColor: NSColor.swTextSecondary,
                    .font: DesignTokens.Typography.body(size: 14)
                ]
            }
            
            attributedString.append(NSAttributedString(string: wordWithSpace, attributes: attributes))
        }
        
        sampleTextView.textStorage?.setAttributedString(attributedString)
    }
    
    private func checkForCompletion() {
        let typedWords = inputTextView.string.components(separatedBy: " ").filter { !$0.isEmpty }
        
        guard typedWords.count >= sampleWords.count else { return }
        
        var allCorrect = true
        for (index, sampleWord) in sampleWords.enumerated() {
            if index >= typedWords.count || typedWords[index] != sampleWord {
                allCorrect = false
                break
            }
        }
        
        if allCorrect {
            endTest(completedEarly: true)
        }
    }
    
    func textDidChange(_ notification: Notification) {
        guard isTestRunning else { return }
        updateSampleTextHighlighting()
        checkForCompletion()
    }
    
    private func finishAndClose() {
        window?.close()
    }
}

private class TypingTestButton: NSButton {
    
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
        font = DesignTokens.Typography.body(size: 14)
        target = self
        self.action = #selector(buttonClicked)
        
        wantsLayer = true
        layer?.cornerRadius = DesignTokens.CornerRadius.medium
    }
    
    @objc private func buttonClicked() {
        actionHandler?()
    }
}
