import SwiftUI

/// Accessibility-first constants. These are not style preferences; they are
/// requirements. The person holding this phone may have limited motor control.
///
/// - Targets are far larger than Apple's 44pt minimum.
/// - Text starts at 24pt and scales with the user's own setting.
/// - No gesture is ever required: no swipe, drag, long-press, or double-tap.
/// - Nothing times out or dismisses itself.
enum Theme {
    /// The one primary button. Most of the bottom of the screen.
    static let primaryButtonHeight: CGFloat = 132
    /// Secondary actions (Show, Speak). Still huge.
    static let secondaryButtonHeight: CGFloat = 76
    /// Minimum hit target for anything tappable, including list rows.
    static let minTarget: CGFloat = 64

    static let cornerRadius: CGFloat = 22
    static let spacing: CGFloat = 16

    /// Base body size before the user's scale is applied. 24pt is the floor.
    static let baseBody: CGFloat = 24
    static let baseShow: CGFloat = 44

    static func body(_ scale: Double) -> Font {
        .system(size: baseBody * scale, weight: .regular, design: .rounded)
    }
    static func show(_ scale: Double) -> Font {
        .system(size: baseShow * scale, weight: .semibold, design: .rounded)
    }
    static func button() -> Font {
        .system(size: 30, weight: .bold, design: .rounded)
    }
    static func label() -> Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }
}

/// A big, plain, high-contrast button. Tap once. That's the only interaction.
struct BigButton: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    var height: CGFloat = Theme.secondaryButtonHeight
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .bold))
                Text(title)
                    .font(Theme.button())
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(.white)
            .background(tint, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
