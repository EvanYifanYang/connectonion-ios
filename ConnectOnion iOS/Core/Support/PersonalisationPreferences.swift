import Foundation
import SwiftUI
import UIKit

enum UIFontPreference: String, CaseIterable, Identifiable, Sendable {
    static let storageKey = "uiFontPreference"

    case system
    case timesNewRoman
    case newYork

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .timesNewRoman: "Times New Roman"
        case .system: "System"
        case .newYork: "New York"
        }
    }

    func font(
        _ style: Font.TextStyle,
        weight: Font.Weight? = nil,
        pointSize: Double = FontSizePreference.defaultUI
    ) -> Font {
        let normalizedPointSize = FontSizePreference.normalizedUI(pointSize)
        let scale = CGFloat(normalizedPointSize / FontSizePreference.defaultUI)
        let resolvedSize = Self.baseSize(for: style) * scale
        let font: Font
        switch self {
        case .timesNewRoman:
            let name = "TimesNewRomanPSMT"
            if UIFont(name: name, size: resolvedSize) != nil {
                font = .custom(name, size: resolvedSize, relativeTo: style)
            } else {
                font = scale == 1 ? .system(style) : .system(size: resolvedSize)
            }
        case .system:
            font = scale == 1 ? .system(style) : .system(size: resolvedSize)
        case .newYork:
            font = scale == 1
                ? .system(style, design: .serif)
                : .system(size: resolvedSize, design: .serif)
        }
        if let weight {
            return font.weight(weight)
        }
        return font
    }

    private static func baseSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .subheadline: 15
        case .callout: 16
        case .caption: 12
        case .caption2: 11
        case .footnote: 13
        default: 17
        }
    }
}

private struct UIFontPreferenceEnvironmentKey: EnvironmentKey {
    static let defaultValue = UIFontPreference.system
}

private struct UIFontSizeEnvironmentKey: EnvironmentKey {
    static let defaultValue = FontSizePreference.defaultUI
}

extension EnvironmentValues {
    var uiFontPreference: UIFontPreference {
        get { self[UIFontPreferenceEnvironmentKey.self] }
        set { self[UIFontPreferenceEnvironmentKey.self] = newValue }
    }

    var uiFontSize: Double {
        get { self[UIFontSizeEnvironmentKey.self] }
        set { self[UIFontSizeEnvironmentKey.self] = newValue }
    }
}

private struct PreferredUIFontModifier: ViewModifier {
    @Environment(\.uiFontPreference) private var preference
    @Environment(\.uiFontSize) private var pointSize

    var style: Font.TextStyle
    var weight: Font.Weight?

    func body(content: Content) -> some View {
        content.font(preference.font(style, weight: weight, pointSize: pointSize))
    }
}

extension View {
    func appFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        modifier(PreferredUIFontModifier(style: style, weight: weight))
    }

    /// Fixed typography for ConnectOnion wordmarks. Brand text must not follow the UI preference.
    func connectOnionBrandFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        font(UIFontPreference.timesNewRoman.font(style, weight: weight))
    }

    /// Always-New-York (serif) brand typography for section headers, nav titles, and agent names.
    /// These surfaces are intentionally exempt from the user's UI-font preference — restoring the
    /// original AppFont brand serif that the typography refactor flattened to the default SF.
    func brandSerifFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        font(UIFontPreference.newYork.font(style, weight: weight))
    }
}

enum CodeFontPreference: String, CaseIterable, Identifiable, Sendable {
    static let storageKey = "codeFontPreference"

    case sfMono
    case menlo
    case courierNew

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sfMono: "SF Mono"
        case .menlo: "Menlo"
        case .courierNew: "Courier New"
        }
    }

    func uiFont(
        textStyle: UIFont.TextStyle = .callout,
        pointSize: Double = FontSizePreference.defaultCode
    ) -> UIFont {
        let baseSize = CGFloat(FontSizePreference.normalizedCode(pointSize))
        let base: UIFont
        switch self {
        case .sfMono:
            base = .monospacedSystemFont(ofSize: baseSize, weight: .regular)
        case .menlo:
            base = UIFont(name: "Menlo-Regular", size: baseSize)
                ?? .monospacedSystemFont(ofSize: baseSize, weight: .regular)
        case .courierNew:
            base = UIFont(name: "CourierNewPSMT", size: baseSize)
                ?? .monospacedSystemFont(ofSize: baseSize, weight: .regular)
        }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }

    func swiftUIFont(
        textStyle: UIFont.TextStyle = .callout,
        pointSize: Double = FontSizePreference.defaultCode
    ) -> Font {
        Font(uiFont(textStyle: textStyle, pointSize: pointSize))
    }
}

enum FontSizePreference {
    static let uiStorageKey = "uiFontSize"
    static let codeStorageKey = "codeFontSize"
    static let defaultUI = 17.0
    static let defaultCode = 16.0
    static let allowedRange = 14.0 ... 18.0

    static func normalizedUI(_ value: Double) -> Double {
        normalized(value, fallback: defaultUI)
    }

    static func normalizedCode(_ value: Double) -> Double {
        normalized(value, fallback: defaultCode)
    }

    private static func normalized(_ value: Double, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, allowedRange.lowerBound), allowedRange.upperBound)
    }
}

enum PersonalityMode: String, CaseIterable, Identifiable, Sendable {
    static let storageKey = "personalityMode"

    case pragmatic
    case friendly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pragmatic: "Pragmatic"
        case .friendly: "Friendly"
        }
    }

    var explanation: String {
        switch self {
        case .pragmatic: "Concise, direct, and task-focused"
        case .friendly: "Warm, collaborative, and helpful"
        }
    }

    var promptInstruction: String {
        switch self {
        case .pragmatic:
            "Use a concise, direct, task-focused tone."
        case .friendly:
            "Use a warm, collaborative, encouraging, and helpful tone."
        }
    }

    @MainActor
    static var saved: PersonalityMode {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let value = PersonalityMode(rawValue: raw) else {
            return .pragmatic
        }
        return value
    }
}
