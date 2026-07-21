//
//  QuietPressButtonStyle.swift
//
//  Purpose: Implements QuietPressButtonStyle for the Design module.
//  Collaborates with: AppColors, AppMotion, AppTheme, AppearanceMode, BrandColor, GlassSurfaceModifier.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

/// A press style that draws NO system highlight platter behind the label — the label itself just dims
/// slightly while pressed. Used for small inline icon buttons (e.g. the row ellipsis menus), where the
/// default press flash reads as a stray shape on the card.
struct QuietPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}
