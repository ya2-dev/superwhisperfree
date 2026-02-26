import Cocoa

final class LineChartView: NSView {
    
    var dataPoints: [Double] = [] {
        didSet { needsDisplay = true }
    }
    
    var barLabels: [String] = [] {
        didSet { needsDisplay = true }
    }
    
    private let topPad: CGFloat = 16
    private let bottomPad: CGFloat = 24
    private let leftPad: CGFloat = 40
    private let rightPad: CGFloat = 12
    
    private let lineWidth: CGFloat = 2
    private let dotRadius: CGFloat = 3
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.swSurface.cgColor
        layer?.cornerRadius = DesignTokens.CornerRadius.medium
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.swSurface.cgColor
        layer?.cornerRadius = DesignTokens.CornerRadius.medium
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        NSColor.swSurface.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: DesignTokens.CornerRadius.medium, yRadius: DesignTokens.CornerRadius.medium).fill()
        
        let chartRect = NSRect(
            x: leftPad,
            y: bottomPad,
            width: bounds.width - leftPad - rightPad,
            height: bounds.height - topPad - bottomPad
        )
        
        let nonZero = dataPoints.filter { $0 > 0 }
        if nonZero.isEmpty {
            drawEmpty(in: chartRect)
            return
        }
        
        drawChart(in: chartRect, ctx: ctx)
    }
    
    // MARK: - Empty state
    
    private func drawEmpty(in rect: NSRect) {
        let ps = NSMutableParagraphStyle()
        ps.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: DesignTokens.Typography.body(size: 13),
            .foregroundColor: NSColor.swTextSecondary,
            .paragraphStyle: ps
        ]
        let text = "No data yet"
        let size = text.size(withAttributes: attrs)
        text.draw(in: NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height), withAttributes: attrs)
    }
    
    // MARK: - Main drawing
    
    private func drawChart(in rect: NSRect, ctx: CGContext) {
        let maxVal = dataPoints.max() ?? 1
        let niceMax = niceRound(maxVal)
        
        drawGridLines(in: rect, ctx: ctx, maxVal: niceMax)
        
        let points = calculatePoints(in: rect, maxVal: niceMax)
        
        guard points.count > 1 else {
            if let p = points.first {
                ctx.setFillColor(NSColor.swAccent.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - dotRadius, y: p.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
            }
            drawXLabels(in: rect, points: points)
            return
        }
        
        drawFill(points: points, in: rect, ctx: ctx)
        drawLine(points: points, ctx: ctx)
        drawDots(points: points, ctx: ctx)
        drawXLabels(in: rect, points: points)
    }
    
    private func calculatePoints(in rect: NSRect, maxVal: Double) -> [CGPoint] {
        guard !dataPoints.isEmpty else { return [] }
        let count = dataPoints.count
        let stepX = count > 1 ? rect.width / CGFloat(count - 1) : 0
        
        return dataPoints.enumerated().map { i, val in
            let x = count > 1 ? rect.minX + CGFloat(i) * stepX : rect.midX
            let normalized = maxVal > 0 ? CGFloat(val / maxVal) : 0
            let y = rect.minY + normalized * rect.height
            return CGPoint(x: x, y: y)
        }
    }
    
    // MARK: - Gradient fill under the line
    
    private func drawFill(points: [CGPoint], in rect: NSRect, ctx: CGContext) {
        guard points.count > 1 else { return }
        
        ctx.saveGState()
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: points.first!.x, y: rect.minY))
        for pt in points {
            path.addLine(to: pt)
        }
        path.addLine(to: CGPoint(x: points.last!.x, y: rect.minY))
        path.closeSubpath()
        
        ctx.addPath(path)
        ctx.clip()
        
        let colors = [
            NSColor.swAccent.withAlphaComponent(0.2).cgColor,
            NSColor.swAccent.withAlphaComponent(0.0).cgColor
        ] as CFArray
        
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.maxY),
                end: CGPoint(x: rect.midX, y: rect.minY),
                options: []
            )
        }
        
        ctx.restoreGState()
    }
    
    // MARK: - Smooth line
    
    private func drawLine(points: [CGPoint], ctx: CGContext) {
        guard points.count > 1 else { return }
        
        ctx.setStrokeColor(NSColor.swAccent.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        
        if points.count == 2 {
            ctx.move(to: points[0])
            ctx.addLine(to: points[1])
        } else {
            ctx.move(to: points[0])
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let midX = (prev.x + curr.x) / 2
                ctx.addCurve(to: curr, control1: CGPoint(x: midX, y: prev.y), control2: CGPoint(x: midX, y: curr.y))
            }
        }
        
        ctx.strokePath()
    }
    
    // MARK: - Dots
    
    private func drawDots(points: [CGPoint], ctx: CGContext) {
        let showDots = points.count <= 31
        guard showDots else { return }
        
        for (i, pt) in points.enumerated() {
            guard dataPoints[i] > 0 else { continue }
            ctx.setFillColor(NSColor.swAccent.cgColor)
            ctx.fillEllipse(in: CGRect(x: pt.x - dotRadius, y: pt.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
        }
    }
    
    // MARK: - Grid + Y-axis labels
    
    private func drawGridLines(in rect: NSRect, ctx: CGContext, maxVal: Double) {
        let lineCount = 4
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.swTextSecondary.withAlphaComponent(0.5)
        ]
        
        ctx.setStrokeColor(NSColor.swTextSecondary.withAlphaComponent(0.08).cgColor)
        ctx.setLineWidth(0.5)
        
        for i in 0...lineCount {
            let frac = CGFloat(i) / CGFloat(lineCount)
            let y = rect.minY + frac * rect.height
            
            ctx.move(to: CGPoint(x: rect.minX, y: y))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: y))
            ctx.strokePath()
            
            let val = maxVal * Double(frac)
            let label = formatAxisValue(val)
            let size = label.size(withAttributes: labelAttrs)
            label.draw(at: NSPoint(x: rect.minX - size.width - 4, y: y - size.height / 2), withAttributes: labelAttrs)
        }
    }
    
    // MARK: - X-axis labels
    
    private func drawXLabels(in rect: NSRect, points: [CGPoint]) {
        guard !barLabels.isEmpty else { return }
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: NSColor.swTextSecondary.withAlphaComponent(0.5)
        ]
        
        let maxLabels = max(1, Int(rect.width / 30))
        let step = max(1, barLabels.count / maxLabels)
        
        for i in stride(from: 0, to: min(barLabels.count, points.count), by: step) {
            let x = points[i].x
            let label = barLabels[i]
            let size = label.size(withAttributes: labelAttrs)
            label.draw(at: NSPoint(x: x - size.width / 2, y: rect.minY - size.height - 3), withAttributes: labelAttrs)
        }
    }
    
    // MARK: - Formatting
    
    private func formatAxisValue(_ val: Double) -> String {
        if val >= 1000 {
            return String(format: "%.0fk", val / 1000)
        }
        return "\(Int(val))"
    }
    
    private func niceRound(_ val: Double) -> Double {
        guard val > 0 else { return 10 }
        let magnitude = pow(10, floor(log10(val)))
        let normalized = val / magnitude
        let nice: Double
        if normalized <= 1.5 { nice = 2 }
        else if normalized <= 3 { nice = 4 }
        else if normalized <= 7 { nice = 8 }
        else { nice = 10 }
        return nice * magnitude
    }
}
