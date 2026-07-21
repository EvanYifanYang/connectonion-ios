//
//  AppTheme.swift
//
//  Purpose: Implements AppTheme for the Design module.
//  Collaborates with: AppColors, AppMotion, AppearanceMode, BrandColor, GlassSurfaceModifier, QuietPressButtonStyle.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI
import UIKit

enum AppTheme {
    static let sidebarWidth: Double = 320
    static let contentMaxWidth: Double = 760
    static let composerMaxWidth: Double = 780
    static let controlCornerRadius: Double = 20
    static let bubbleCornerRadius: Double = 22
    static let compactRadius: Double = 14
    static let standardSpacing: Double = 12

    static let contrastFill = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.secondarySystemFill : UIColor.label
    })

    static let contrastForeground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.label : UIColor.systemBackground
    })

    static let selectionFill = Color(uiColor: UIColor { traits in
        UIColor.label
            .resolvedColor(with: traits)
            .withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.14 : 0.08)
    })
}
