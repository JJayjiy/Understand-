import SwiftUI

/// Visual identity and accessibility constants.
///
/// The accessibility numbers are requirements, not preferences. The person
/// holding this phone may have limited motor control.
///
/// - Targets far larger than Apple's 44pt minimum.
/// - Text starts at 24pt and scales with the user's own setting.
/// - No gesture is ever required: no swipe, drag, long-press, or double-tap.
/// - Nothing times out or dismisses itself.
///
/// The visual identity comes from the app icon: deep blue to teal, white
/// waveform. Calm and high-contrast. Not playful — adults and clinicians use
/// this too — but not clinical either.
enum Theme {

    // MARK: Colors

    /// Icon blue. Primary action, wordmark.
    static let blue = Color(red: 0.09, green: 0.31, blue: 0.62)
    /// Icon teal. Secondary accent, gradients.
    static let teal = Color(red: 0.06, green: 0.52, blue: 0.59)
    /// Live / hearing you.
    static let live = Color(red: 0.13, green: 0.68, blue: 0.42)
    /// Stop / destructive.
    static let stop = Color(red: 0.80, green: 0.22, blue: 0.24)

    static let brand = LinearGradient(colors: [blue, teal],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Warm off-white in light mode, deep navy in dark. Never pure white/black —
    /// less glare for long reading, and the cards need something to sit on.
    static let canvas = Color("Canvas", bundle: nil, fallbackLight: Color(red: 0.97, green: 0.97, blue: 0.96),
                              fallbackDark: Color(red: 0.06, green: 0.08, blue: 0.12))
    static let card = Color("Card", bundle: nil, fallbackLight: .white,
                            fallbackDark: Color(red: 0.11, green: 0.14, blue: 0.19))

    // MARK: Sizing

    /// The hero Listen button. A circle; this is its diameter.
    static let heroSize: CGFloat = 168
    /// Secondary actions (Show, Speak).
    static let secondaryButtonHeight: CGFloat = 72
    /// Minimum hit target for anything tappable.
    static let minTarget: CGFloat = 64

    static let cornerRadius: CGFloat = 24
    static let spacing: CGFloat = 16

    /// Base sizes before the user's scale is applied. Older lines sit at 22
    /// so the newest one reads as "current"; the newest is never below 24,
    /// and the user's own scale lifts everything together.
    static let baseBody: CGFloat = 22
    static let baseLatest: CGFloat = 30
    static let baseShow: CGFloat = 48

    static func body(_ scale: Double) -> Font {
        .system(size: baseBody * scale, weight: .regular, design: .rounded)
    }
    static func latest(_ scale: Double) -> Font {
        .system(size: baseLatest * scale, weight: .medium, design: .rounded)
    }
    static func show(_ scale: Double) -> Font {
        .system(size: baseShow * scale, weight: .semibold, design: .rounded)
    }
    static func button() -> Font {
        .system(size: 24, weight: .semibold, design: .rounded)
    }
    static func label() -> Font {
        .system(size: 19, weight: .medium, design: .rounded)
    }
    static func wordmark() -> Font {
        .system(size: 26, weight: .bold, design: .rounded)
    }
}

// Asset-catalog colors with code fallbacks, so the app builds before anyone
// adds a color set and still adapts to dark mode.
extension Color {
    init(_ name: String, bundle: Bundle?, fallbackLight: Color, fallbackDark: Color) {
        if UIColor(named: name) != nil {
            self = Color(name)
        } else {
            self = Color(UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(fallbackDark) : UIColor(fallbackLight)
            })
        }
    }
}

// MARK: - Components

/// A large pill button. One tap. That's the only interaction.
struct PillButton: View {
    let title: String
    let systemImage: String
    var tint: Color = Theme.blue
    var filled: Bool = true
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage).font(.system(size: 24, weight: .semibold))
                Text(title).font(Theme.button())
            }
            .frame(maxWidth: .infinity, minHeight: Theme.secondaryButtonHeight)
            .foregroundStyle(filled ? .white : tint)
            .background(
                Capsule().fill(filled ? tint : tint.opacity(0.12))
            )
            .overlay(Capsule().strokeBorder(tint.opacity(filled ? 0 : 0.35), lineWidth: 1.5))
            .opacity(enabled ? 1 : 0.38)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

/// The one primary control. A circle that pulses while listening and fills
/// with the live mic level, so "is it working" is answered without reading.
struct HeroButton: View {
    let listening: Bool
    let level: Float          // 0...1
    let hearing: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulse ring — only while listening.
                if listening {
                    Circle()
                        .stroke((hearing ? Theme.live : Theme.blue).opacity(0.28), lineWidth: 10)
                        .scaleEffect(pulse ? 1.22 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)
                }

                // Level ring — fills clockwise with the mic level.
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(listening ? max(0.02, level) : 0))
                    .stroke(hearing ? Theme.live : Theme.teal,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.06), value: level)

                // Face.
                Circle()
                    .fill(listening ? AnyShapeStyle(Theme.stop) : AnyShapeStyle(Theme.brand))
                    .padding(12)
                    .shadow(color: (listening ? Theme.stop : Theme.blue).opacity(0.35), radius: 18, y: 8)

                VStack(spacing: 6) {
                    Image(systemName: listening ? "stop.fill" : "waveform")
                        .font(.system(size: 46, weight: .bold))
                    Text(listening ? "Stop" : "Listen")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
            }
            .frame(width: Theme.heroSize, height: Theme.heroSize)
        }
        .buttonStyle(PressStyle())
        .onAppear { pulse = true }
        .onChange(of: listening) { _, on in pulse = on }
        .accessibilityLabel(listening ? "Stop listening" : "Listen")
        .accessibilityHint(listening ? "" : "Starts listening. Speak, then pause.")
    }
}

/// Gentle press feedback without a gesture requirement.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Small status capsule: "Ready", "Listening", "Hearing you".
struct StatusPill: View {
    let text: String
    let color: Color
    let active: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
                .symbolEffect(.pulse, isActive: active)
            Text(text).font(Theme.label()).foregroundStyle(color)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Capsule().fill(color.opacity(0.12)))
        .accessibilityElement(children: .combine)
    }
}
