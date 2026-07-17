import SwiftUI
import UIKit

// MARK: - Brand Palette
// Warm tones: cream, espresso brown, terracotta — adaptive in Dark Mode.
//
// `espresso` and `terracotta` are the app's text/icon colours and flip to
// lighter warm tones in dark mode for contrast. The `*Solid` variants keep the
// original brand values in both modes — use them for surfaces that must stay
// brown regardless of appearance (splash screen, map pins).

extension Color {

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { tc in tc.userInterfaceStyle == .dark ? dark : light })
    }

    // Fixed brand colours (same in light + dark)
    static let espressoSolid   = Color(red: 0.243, green: 0.122, blue: 0.000)   // #3E1F00
    static let terracottaSolid = Color(red: 0.769, green: 0.384, blue: 0.176)   // #C4622D
    static let cream           = Color(red: 0.961, green: 0.902, blue: 0.784)   // #F5E6C8

    /// Primary text/icon colour: espresso brown in light, warm latte in dark.
    static var espresso: Color {
        adaptive(light: UIColor(red: 0.243, green: 0.122, blue: 0.000, alpha: 1),
                 dark:  UIColor(red: 0.925, green: 0.875, blue: 0.784, alpha: 1))   // #ECDFC8
    }

    /// Accent colour: terracotta in light, brighter copper in dark.
    static var terracotta: Color {
        adaptive(light: UIColor(red: 0.769, green: 0.384, blue: 0.176, alpha: 1),
                 dark:  UIColor(red: 0.878, green: 0.541, blue: 0.341, alpha: 1))   // #E08A57
    }

    /// Foreground for controls filled with `espresso` — white on brown in
    /// light mode, dark roast on latte in dark mode.
    static var onEspresso: Color {
        adaptive(light: .white,
                 dark:  UIColor(red: 0.165, green: 0.110, blue: 0.055, alpha: 1))
    }

    /// Adaptive background: warm white in light mode, warm dark roast in dark.
    static var creamBackground: Color {
        adaptive(light: UIColor(red: 0.992, green: 0.973, blue: 0.941, alpha: 1),
                 dark:  UIColor(red: 0.165, green: 0.125, blue: 0.094, alpha: 1))   // #2A2018
    }

    /// Adaptive card surface, elevated above `creamBackground`.
    static var cardBackground: Color {
        adaptive(light: .white,
                 dark:  UIColor(red: 0.227, green: 0.173, blue: 0.122, alpha: 1))   // #3A2C1F
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
