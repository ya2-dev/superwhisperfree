import Cocoa

final class WaveformView: NSView {
    
    private let barCount = 5
    private var barLayers: [CALayer] = []
    private var levels: [Float] = []
    private var isAnimating = false
    private var targetLevel: Float = 0.0
    
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    private let minBarHeight: CGFloat = 4
    private let maxBarHeight: CGFloat = 24
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupBars()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBars()
    }
    
    private func setupBars() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        levels = Array(repeating: 0, count: barCount)
        
        for _ in 0..<barCount {
            let barLayer = CALayer()
            barLayer.backgroundColor = NSColor.white.cgColor
            barLayer.cornerRadius = 2
            layer?.addSublayer(barLayer)
            barLayers.append(barLayer)
        }
        
        layoutBars()
    }
    
    override func layout() {
        super.layout()
        layoutBars()
    }
    
    private func layoutBars() {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        for (index, barLayer) in barLayers.enumerated() {
            let x = startX + CGFloat(index) * (barWidth + barSpacing)
            let height = heightForLevel(levels[index])
            let y = centerY - height / 2
            
            barLayer.frame = CGRect(x: x, y: y, width: barWidth, height: height)
        }
        
        CATransaction.commit()
    }
    
    func updateLevel(_ level: Float) {
        targetLevel = level
        levels.removeFirst()
        levels.append(level)
        
        if !isAnimating {
            animateBars()
        }
    }
    
    func reset() {
        levels = Array(repeating: 0, count: barCount)
        targetLevel = 0
        animateBars()
    }
    
    func startAnimating() {
        isAnimating = true
        runAnimationLoop()
    }
    
    func stopAnimating() {
        isAnimating = false
        reset()
    }
    
    private func runAnimationLoop() {
        guard isAnimating else { return }
        
        let heights: [CGFloat] = [0.3, 0.6, 1.0, 0.6, 0.3]
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        for (index, barLayer) in barLayers.enumerated() {
            let baseHeight = heights[index]
            let levelMultiplier = CGFloat(0.3 + targetLevel * 0.7)
            let randomVariation = CGFloat.random(in: 0.8...1.2)
            let height = max(minBarHeight, baseHeight * maxBarHeight * levelMultiplier * randomVariation)
            
            let x = startX + CGFloat(index) * (barWidth + barSpacing)
            let y = centerY - height / 2
            
            barLayer.frame = CGRect(x: x, y: y, width: barWidth, height: height)
        }
        
        CATransaction.commit()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.runAnimationLoop()
        }
    }
    
    private func animateBars() {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.08)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        
        for (index, barLayer) in barLayers.enumerated() {
            let x = startX + CGFloat(index) * (barWidth + barSpacing)
            let height = heightForLevel(levels[index])
            let y = centerY - height / 2
            
            barLayer.frame = CGRect(x: x, y: y, width: barWidth, height: height)
        }
        
        CATransaction.commit()
    }
    
    private func heightForLevel(_ level: Float) -> CGFloat {
        let normalizedLevel = CGFloat(max(0, min(1, level)))
        return minBarHeight + normalizedLevel * (maxBarHeight - minBarHeight)
    }
    
    override var intrinsicContentSize: NSSize {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        return NSSize(width: totalWidth, height: maxBarHeight)
    }
}
