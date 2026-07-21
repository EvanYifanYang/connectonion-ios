//
//  OnionPeelLogoView.swift
//
//  Purpose: Implements OnionPeelLogoView for the Features/Shell module.
//  Collaborates with: AgentAvatar, AgentListView, AgentSidebarRow, AppShellView, ConnectOnionWordmark, ConversationSidebarRow.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Lottie
import SwiftUI

struct OnionPeelLogoView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LottieView(animation: .named("OnionPeel"))
            .resizable()
            .playbackMode(playbackMode)
            .animationSpeed(0.9)
            .backgroundBehavior(.pauseAndRestore)
            .allowsHitTesting(false)
    }

    private var playbackMode: LottiePlaybackMode {
        if reduceMotion {
            .paused(at: .progress(0))
        } else {
            .playing(.fromProgress(0, toProgress: 1, loopMode: .loop))
        }
    }
}

#Preview("Onion Peel Logo") {
    OnionPeelLogoView()
        .frame(width: 62, height: 62)
        .padding()
}
