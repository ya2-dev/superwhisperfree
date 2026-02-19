import Cocoa

final class LineChartView: NSView {
    
    var dataPoints: [Double] = [] {
        didSet {
            needsDisplay = true
        }
    }
    
    private let padding: CGFloat = 20
    private let lineWidth: CGFloat = 2
    private let dotDiameter: CGFloat = 6
    
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
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        NSColor.swSurface.setFill()
        let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: DesignTokens.CornerRadius.medium, yRadius: DesignTokens.CornerRadius.medium)
        backgroundPath.fill()
        
        let graphRect = NSRect(
            x: padding,
            y: padding,
            width: bounds.width - (padding * 2),
            height: bounds.height - (padding * 2)
        )
        
        let nonZeroPoints = dataPoints.filter { $0 > 0 }
        if nonZeroPoints.isEmpty {
            drawEmptyState(in: graphRect, context: context)
            return
        }
        
        drawChart(in: graphRect, context: context)
    }
    
    private func drawEmptyState(in rect: NSRect, context: CGContext) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: DesignTokens.Typography.body(size: 14),
            .foregroundColor: NSColor.swTextSecondary,
            .paragraphStyle: paragraphStyle
        ]
        
        let text = "No data yet"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    private func drawChart(in rect: NSRect, context: CGContext) {
        guard dataPoints.count > 1 else {
            if dataPoints.count == 1 {
                drawSinglePoint(in: rect, context: context)
            }
            return
        }
        
        let maxValue = dataPoints.max() ?? 1
        let minValue: Double = 0
        let valueRange = max(maxValue - minValue, 1)
        
        let points = calculatePoints(in: rect, minValue: minValue, valueRange: valueRange)
        
        drawLine(points: points, context: context)
        drawDots(points: points, context: context)
    }
    
    private func drawSinglePoint(in rect: NSRect, context: CGContext) {
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        
        context.setFillColor(NSColor.swAccent.cgColor)
        context.fillEllipse(in: CGRect(
            x: centerPoint.x - dotDiameter / 2,
            y: centerPoint.y - dotDiameter / 2,
            width: dotDiameter,
            height: dotDiameter
        ))
    }
    
    private func calculatePoints(in rect: NSRect, minValue: Double, valueRange: Double) -> [CGPoint] {
        guard dataPoints.count > 0 else { return [] }
        
        let stepX = dataPoints.count > 1 ? rect.width / CGFloat(dataPoints.count - 1) : 0
        
        return dataPoints.enumerated().map { index, value in
            let x = rect.minX + CGFloat(index) * stepX
            let normalizedValue = (value - minValue) / valueRange
            let y = rect.minY + CGFloat(normalizedValue) * rect.height
            return CGPoint(x: x, y: y)
        }
    }
    
    private func drawLine(points: [CGPoint], context: CGContext) {
        guard points.count > 1 else { return }
        
        context.setStrokeColor(NSColor.swAccent.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        context.move(to: points[0])
        for i in 1..<points.count {
            context.addLine(to: points[i])
        }
        
        context.strokePath()
    }
    
    private func drawDots(points: [CGPoint], context: CGContext) {
        context.setFillColor(NSColor.swAccent.cgColor)
        
        for point in points {
            context.fillEllipse(in: CGRect(
                x: point.x - dotDiameter / 2,
                y: point.y - dotDiameter / 2,
                width: dotDiameter,
                height: dotDiameter
            ))
        }
    }
}
