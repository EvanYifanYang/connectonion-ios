//
//  AppearanceMode.swift
//
//  Purpose: Implements AppearanceMode for the Design module.
//  Collaborates with: AppColors, AppMotion, AppTheme, BrandColor, GlassSurfaceModifier, QuietPressButtonStyle.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

/// The user's theme preference, persisted via `@AppStorage(AppearanceMode.storageKey)` and applied
/// with `.preferredColorScheme` at the app root.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "iphone"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    /// `nil` means "follow the system", which is what `.preferredColorScheme(nil)` does.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
