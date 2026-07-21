//
//  LaunchSplashView.swift
//
//  Purpose: Implements LaunchSplashView for the Features/Shell module.
//  Collaborates with: AgentAvatar, AgentListView, AgentSidebarRow, AppShellView, ConnectOnionWordmark, ConversationSidebarRow.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

/// The launch choreography (option B): the onion assembles itself layer-by-layer while the wordmark
/// waves in left-to-right; a beat later everything disassembles — onion inner→outer, wordmark
/// left→right — as the warm backdrop fades to hand off to the app already sitting behind it. Tap to
/// skip. Suppressed under UI testing.
struct LaunchSplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var assembled = false
    @State private var dismissing = false
    @State private var done = false

    // OUTER → INNER, matching OnionRevealView.
    private let onionLayers = [
        "onion_1_black", "onion_2_purple", "onion_3_white", "onion_4_purple",
        "onion_5_white", "onion_6_purple", "onion_7_white", "onion_8_core"
    ]
    private let word = Array("ConnectOnion")

    var body: some View {
        ZStack {
            Color.appCanvas
                .ignoresSafeArea()
                .opacity(dismissing ? 0 : 1)
                .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.75), value: dismissing)

            VStack(spacing: 22) {
                onion
                wordmark
            }
        }
        .contentShape(.rect)
        .onTapGesture { skip() }
        .accessibilityElement()
        .accessibilityLabel("ConnectOnion")
        .task { await runTimeline() }
    }

    private var onion: some View {
        ZStack {
            ForEach(Array(onionLayers.enumerated()), id: \.offset) { index, name in
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(reduceMotion || assembled ? 1 : 0.82)
                    .opacity(assembled && !dismissing ? 1 : 0)
                    // Assemble: outer peel first, springing inward.
                    .animation(assemblyAnimation(for: index), value: assembled)
                    // Disassemble: inner core first, back out to the peel.
                    .animation(disassemblyAnimation(for: index), value: dismissing)
            }
        }
        .frame(width: 92, height: 92)
    }

    private var wordmark: some View {
        HStack(spacing: 0) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, ch in
                Text(String(ch))
                    .offset(y: reduceMotion || assembled ? 0 : 12)
                    .opacity(assembled && !dismissing ? 1 : 0)
                    // Wave in, then wave out — both left → right.
                    .animation(wordAssemblyAnimation(for: index), value: assembled)
                    .animation(wordDisassemblyAnimation(for: index), value: dismissing)
            }
        }
        .connectOnionBrandFont(.largeTitle, weight: .semibold)
        .foregroundStyle(.primary)
    }

    private func runTimeline() async {
        assembled = true
        if reduceMotion {
            // Keep the brand handoff, but limit it to a brief opacity-only transition.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, !done else { return }
            dismissing = true
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            finish()
            return
        }

        // assemble (~1.2s) + hold (~0.5s)
        try? await Task.sleep(for: .seconds(1.7))
        guard !Task.isCancelled, !done else { return }
        dismissing = true
        // disassemble + backdrop fade
        try? await Task.sleep(for: .seconds(0.95))
        guard !Task.isCancelled else { return }
        finish()
    }

    private func assemblyAnimation(for index: Int) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .spring(response: 0.5, dampingFraction: 0.62).delay(Double(index) * 0.085)
    }

    private func disassemblyAnimation(for index: Int) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .easeIn(duration: 0.32).delay(Double(onionLayers.count - 1 - index) * 0.06)
    }

    private func wordAssemblyAnimation(for index: Int) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .spring(response: 0.45, dampingFraction: 0.7).delay(Double(index) * 0.045)
    }

    private func wordDisassemblyAnimation(for index: Int) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .easeIn(duration: 0.3).delay(Double(index) * 0.045)
    }

    private func skip() {
        guard !done, !dismissing else { return }
        dismissing = true
        Task { try? await Task.sleep(for: .milliseconds(450)); finish() }
    }

    private func finish() {
        guard !done else { return }
        done = true
        onFinished()
    }
}

#Preview("Launch Splash") {
    LaunchSplashView(onFinished: {})
}
