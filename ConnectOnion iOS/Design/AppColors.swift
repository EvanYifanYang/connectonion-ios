import SwiftUI
import UIKit

/// App surface palette. iOS's system backgrounds go **pure black** (#000) in dark mode; that reads
/// harsh next to our content, so in dark mode we swap in a **warm off-black** family (a faint red/green
/// bias over blue, à la Claude) with clearly-separated elevation steps. Light mode keeps the exact
/// system values, so nothing there changes.
extension Color {
    /// The app canvas — the backdrop behind every screen. Dark: warm off-black. Light: grouped bg.
    static let appCanvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.106, blue: 0.098, alpha: 1) // ~#1C1B19
            : .systemGroupedBackground
    })

    /// One step up from the canvas — cards, rows, grouped sections. Dark: warm gray. Light: white.
    static let appElevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.165, green: 0.157, blue: 0.145, alpha: 1) // ~#2A2825
            : .secondarySystemGroupedBackground
    })

    /// Two steps up — inset surfaces (code blocks, nested tiles, inputs). Dark: lighter warm gray.
    static let appElevated2 = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.212, green: 0.200, blue: 0.184, alpha: 1) // ~#363430
            : .tertiarySystemBackground
    })

    /// The user's own message bubble — a touch brighter than a card so the turn stands out.
    static let appUserBubble = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.188, green: 0.176, blue: 0.161, alpha: 1) // ~#302D29
            : .systemGray5
    })
}
