import SwiftUI
import Testing
import UIKit
@testable import ConnectOnion_iOS

@Suite("Personalisation preferences")
struct PersonalisationPreferencesTests {
    @Test func preferenceDefaultsAndLabelsRemainStable() {
        #expect(UIFontPreference.allCases.first == .system)
        #expect(UIFontPreference.timesNewRoman.displayName == "Times New Roman")
        #expect(FontSizePreference.defaultUI == 17)
        #expect(FontSizePreference.defaultCode == 16)
        #expect(FontSizePreference.allowedRange == 14 ... 18)
        #expect(CodeFontPreference.sfMono.displayName == "SF Mono")
        #expect(PersonalityMode.pragmatic.explanation.contains("task-focused"))
        #expect(PersonalityMode.friendly.explanation.contains("collaborative"))
    }

    @Test func everyCodePreferenceResolvesToAMonospacedFont() {
        for preference in CodeFontPreference.allCases {
            let font = preference.uiFont()
            #expect(font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        }
    }
}

@Suite("Syntax highlighting")
struct SyntaxHighlightingTests {
    @Test @MainActor func explicitLanguagesHighlightWithoutChangingCode() throws {
        let examples = [
            ("swift", "let greeting = \"Hello\""),
            ("python", "print('Hello')"),
            ("json", "{\"enabled\": true}")
        ]

        for (language, code) in examples {
            let highlighted = try #require(SyntaxHighlightCache.shared.highlight(
                code: code,
                language: language,
                font: .sfMono,
                colorScheme: .light
            ))
            #expect(String(highlighted.characters) == code)
        }
    }

    @Test @MainActor func unlabeledCodeUsesAutomaticDetection() throws {
        let code = "func greet(name string) string { return \"Hello \" + name }"
        let highlighted = try #require(SyntaxHighlightCache.shared.highlight(
            code: code,
            language: nil,
            font: .menlo,
            colorScheme: .dark
        ))

        #expect(String(highlighted.characters) == code)
    }

    @Test @MainActor func unknownExplicitLanguageFallsBackToPlainRendering() {
        let highlighted = SyntaxHighlightCache.shared.highlight(
            code: "some code",
            language: "not-a-real-language",
            font: .courierNew,
            colorScheme: .light
        )

        #expect(highlighted == nil)
    }
}
