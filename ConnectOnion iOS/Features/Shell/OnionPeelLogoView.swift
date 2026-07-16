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
