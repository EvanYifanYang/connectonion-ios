import SwiftUI
import UIKit

/// App surface palette. iOS's system backgrounds go **pure black** (#000) in dark mode; that reads
/// harsh next to our content, so in dark mode we swap in a **warm off-black** family (a faint red/green
/// bias over blue, à la Claude) with clearly-separated elevation steps. Light mode keeps the exact
/// system values, so nothing there changes.
extension Color {
    /// The app canvas — the backdrop behind the plain (non-Form) screens: agent list, agent home,
    /// landing, chat. Dark: warm gray (Claude-like, clearly not black). Light: plain system
    /// background (white), as before.
    static let appCanvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.149, green: 0.145, blue: 0.137, alpha: 1) // ~#262523
            : .systemBackground
    })

    /// The canvas behind Form/grouped screens (Settings, agent editor/detail). Dark: same warm
    /// gray. Light: the grouped background (#F2F2F7) so white sections still pop, as before.
    static let appGroupedCanvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.149, green: 0.145, blue: 0.137, alpha: 1) // ~#262523
            : .systemGroupedBackground
    })

    /// One step up from the canvas — cards, rows, grouped sections. Dark: warm gray. Light: white.
    static let appElevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.204, green: 0.196, blue: 0.184, alpha: 1) // ~#34322F
            : .secondarySystemGroupedBackground
    })

    /// Two steps up — inset surfaces (code blocks, nested tiles, inputs). Dark: lighter warm gray.
    static let appElevated2 = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.251, green: 0.243, blue: 0.227, alpha: 1) // ~#403E3A
            : .tertiarySystemBackground
    })

    /// In-chat cards (tool-call groups, code blocks, tables) sitting on the PLAIN canvas. The canvas
    /// is white in light mode, so these need a visible warm paper gray there (appElevated is white —
    /// it's for cards on the grouped gray canvas). Dark matches the elevated steps.
    static let appChatCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.204, green: 0.196, blue: 0.184, alpha: 1) // ~#34322F
            : UIColor(red: 0.961, green: 0.953, blue: 0.937, alpha: 1) // ~#F5F3EF
    })

    /// A nested surface inside an in-chat card (e.g. a tool result inside the group card).
    static let appChatInset = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.251, green: 0.243, blue: 0.227, alpha: 1) // ~#403E3A
            : UIColor(red: 0.922, green: 0.914, blue: 0.894, alpha: 1) // ~#EBE9E4
    })

    /// The user's own message bubble — a touch brighter than a card so the turn stands out.
    static let appUserBubble = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.227, green: 0.216, blue: 0.200, alpha: 1) // ~#3A3733
            : .systemGray5
    })
}
