import SwiftUI
import UIKit

// MARK: - Brand Palette
// Warm tones: cream, espresso brown, terracotta — adapts to Dark Mode via UIColor.

extension Color {

    // Fixed brand colours (same in light + dark)
    static let espresso   = Color(red: 0.243, green: 0.122, blue: 0.000)   // #3E1F00
    static let terracotta = Color(red: 0.769, green: 0.384, blue: 0.176)   // #C4622D
    static let cream      = Color(red: 0.961, green: 0.902, blue: 0.784)   // #F5E6C8

    /// Adaptive background: warm white in light mode, deep espresso in dark mode
    static var creamBackground: Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.07, blue: 0.04, alpha: 1)
                : UIColor(red: 0.992, green: 0.973, blue: 0.941, alpha: 1)
        })
    }

    /// Adaptive card surface
    static var cardBackground: Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1)
                : UIColor.white
        })
    }

    /// Convenience: initialise from a 6-char hex string (e.g. "C4622D")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
