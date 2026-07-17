import SwiftUI
import UIKit

/// App surface palette. iOS's system backgrounds go **pure black** (#000) in dark mode; that reads
/// harsh next to our content, so in dark mode we swap in a **warm off-black** family (a faint red/green
/// bias over blue, à la Claude) with clearly-separated elevation steps. Light mode keeps the exact
/// system values, so nothing there changes.
extension Color {
    /// The app canvas — the backdrop behind the plain (non-Form) screens: agent list, agent home,
    /// landing, chat. Dark: warm gray (Claude-like, clearly not black). Light: warm paper white —
    /// softer than pure white and it ties the serif/paper brand together.
    static let appCanvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.149, green: 0.145, blue: 0.137, alpha: 1) // ~#262523
            : UIColor(red: 0.980, green: 0.976, blue: 0.961, alpha: 1) // ~#FAF9F5
    })

    /// The canvas behind Form/grouped screens (Settings, agent editor/detail). Dark: same warm
    /// gray. Light: a warm grouped gray (the system #F2F2F7 is cool and clashes with the paper tone).
    static let appGroupedCanvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.149, green: 0.145, blue: 0.137, alpha: 1) // ~#262523
            : UIColor(red: 0.945, green: 0.937, blue: 0.918, alpha: 1) // ~#F1EFEA
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

    /// In-chat cards (the tool-call group) sitting on the plain canvas — a deeper warm paper gray,
    /// clearly separated from the paper-white canvas. Dark matches the elevated steps.
    static let appChatCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.204, green: 0.196, blue: 0.184, alpha: 1) // ~#34322F
            : UIColor(red: 0.937, green: 0.929, blue: 0.906, alpha: 1) // ~#EFEDE7
    })

    /// A nested surface inside an in-chat card (e.g. a tool result inside the group card).
    static let appChatInset = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.251, green: 0.243, blue: 0.227, alpha: 1) // ~#403E3A
            : UIColor(red: 0.902, green: 0.890, blue: 0.859, alpha: 1) // ~#E6E3DB
    })

    /// Code blocks: white paper card on the warm canvas (defined by its hairline border), matching
    /// the reference editorial look. Dark keeps the warm elevated panel.
    static let appCodeBlock = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.204, green: 0.196, blue: 0.184, alpha: 1) // ~#34322F
            : .white
    })

    /// The user's own message bubble — a touch brighter than a card so the turn stands out.
    /// Light: warm gray (systemGray5 is cool and would read blue on the paper canvas).
    static let appUserBubble = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.227, green: 0.216, blue: 0.200, alpha: 1) // ~#3A3733
            : UIColor(red: 0.918, green: 0.910, blue: 0.882, alpha: 1) // ~#EAE8E1
    })
}
