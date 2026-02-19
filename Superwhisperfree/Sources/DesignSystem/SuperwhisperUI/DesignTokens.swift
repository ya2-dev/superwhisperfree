import Cocoa

enum DesignTokens {
    
    enum Colors {
        static let background = "#0A0A0A"
        static let surface = "#141414"
        static let surfaceHover = "#1A1A1A"
        static let text = "#FFFFFF"
        static let textSecondary = "#888888"
        static let accent = "#FFFFFF"
        static let error = "#FF4444"
        static let success = "#44FF44"
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
    
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }
    
    enum Typography {
        static func heading(size: CGFloat = 24) -> NSFont {
            if let montserrat = NSFont(name: "Montserrat-SemiBold", size: size) {
                return montserrat
            }
            return NSFont.boldSystemFont(ofSize: size)
        }
        
        static func body(size: CGFloat = 14) -> NSFont {
            if let montserrat = NSFont(name: "Montserrat-Regular", size: size) {
                return montserrat
            }
            return NSFont.systemFont(ofSize: size)
        }
        
        static func mono(size: CGFloat = 13) -> NSFont {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}

extension NSColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    static var swBackground: NSColor { NSColor(hex: DesignTokens.Colors.background) }
    static var swSurface: NSColor { NSColor(hex: DesignTokens.Colors.surface) }
    static var swSurfaceHover: NSColor { NSColor(hex: DesignTokens.Colors.surfaceHover) }
    static var swText: NSColor { NSColor(hex: DesignTokens.Colors.text) }
    static var swTextSecondary: NSColor { NSColor(hex: DesignTokens.Colors.textSecondary) }
    static var swAccent: NSColor { NSColor(hex: DesignTokens.Colors.accent) }
    static var swError: NSColor { NSColor(hex: DesignTokens.Colors.error) }
    static var swSuccess: NSColor { NSColor(hex: DesignTokens.Colors.success) }
}
