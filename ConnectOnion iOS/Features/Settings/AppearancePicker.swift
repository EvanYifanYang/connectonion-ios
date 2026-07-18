import SwiftUI

/// The Light / Dark / System theme picker rendered as three tappable "window" swatches (like iOS
/// Settings), each with an onion accent dot; the selected swatch gets an onion ring + label.
struct AppearancePicker: View {
    @Binding var selection: AppearanceMode

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppearanceMode.allCases) { mode in
                swatch(mode)
            }
        }
    }

    private func swatch(_ mode: AppearanceMode) -> some View {
        let selected = selection == mode
        return VStack(spacing: 8) {
            AppearanceSwatchPreview(mode: mode)
                .frame(height: 66)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            selected ? Color.onion : Color(uiColor: .separator),
                            lineWidth: selected ? 2.5 : 1
                        )
                }

            Text(mode.label)
                .appFont(.footnote)
                .foregroundStyle(selected ? Color.onion : .secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(AppMotion.quick) { selection = mode }
        }
        .accessibilityElement()
        .accessibilityLabel(mode.label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct AppearanceSwatchPreview: View {
    var mode: AppearanceMode

    var body: some View {
        ZStack {
            base
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private var base: some View {
        switch mode {
        case .light:
            Color.white
        case .dark:
            Color(white: 0.11)
        case .system:
            ZStack {
                Color.white
                DiagonalHalf().fill(Color(white: 0.11))
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 5) {
            Capsule().fill(Color.gray.opacity(0.55)).frame(width: 34, height: 5)
            Capsule().fill(Color.gray.opacity(0.55)).frame(width: 22, height: 5)
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                Circle().fill(Color.onion).frame(width: 12, height: 12)
            }
        }
        .padding(10)
    }
}

/// Bottom-right triangle, used to paint the "System" swatch's dark half.
private struct DiagonalHalf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Appearance Picker") {
    @Previewable @State var mode: AppearanceMode = .system
    return AppearancePicker(selection: $mode)
        .padding()
}
