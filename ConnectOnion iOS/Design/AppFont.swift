import SwiftUI

/// The app's small type system. Body stays SF (system default); a tasteful **serif** (system New York —
/// no bundled fonts, zero licensing) is reserved for a few hero/section headlines, and **SF Mono** for
/// `0x…` addresses and keys. Uses relative `.system(_:design:)` styles so Dynamic Type still scales.
enum AppFont {
    /// Serif display for full-screen hero / empty-state headlines.
    static let hero = Font.system(.largeTitle, design: .serif).weight(.semibold)

    /// Smaller serif subtitle paired under `hero` (same typeface, quieter).
    static let heroSubtitle = Font.system(.title3, design: .serif)

    /// Serif wordmark for the top bar — a touch larger than section titles so the brand reads.
    static let wordmark = Font.system(.title3, design: .serif).weight(.semibold)

    /// Serif for prominent in-context titles (e.g. an agent's name in its header).
    static let title = Font.system(.title2, design: .serif).weight(.semibold)

    /// Serif for section titles.
    static let sectionSerif = Font.system(.headline, design: .serif)

    /// Monospaced for `0x…` addresses and keys.
    static let mono = Font.system(.callout, design: .monospaced)

    /// Small monospaced (short/truncated addresses, captions).
    static let monoCaption = Font.system(.caption, design: .monospaced)

    /// Serif for agent names in list rows (sidebar + settings).
    static let rowName = Font.system(.body, design: .serif)
}
