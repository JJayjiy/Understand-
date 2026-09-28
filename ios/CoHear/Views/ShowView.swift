import SwiftUI

/// The screen you turn around and point at someone.
///
/// Maximum text, nothing else. Readable across a table. This is the only place
/// the transcript is meant to be seen by anyone other than the speaker, and
/// the speaker got here by tapping Show — a deliberate act.
///
/// Always dark: white text on near-black reads best across distance and under
/// any lighting, and it looks intentional rather than like a blank page.
struct ShowView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(red: 0.05, green: 0.06, blue: 0.09).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // visibleUtterances already excludes lines attributed to other
                    // voices — what gets turned around is the speaker's words only.
                    ForEach(session.visibleUtterances) { u in
                        let low = session.showConfidence && u.confidence == .low
                        VStack(alignment: .leading, spacing: 8) {
                            Text(u.text)
                                .font(Theme.show(session.textScale))
                                .foregroundStyle(low ? Color.white.opacity(0.55) : .white)
                                .italic(low)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                            if low {
                                Label("might not be right", systemImage: "questionmark.circle")
                                    .font(Theme.label())
                                    .foregroundStyle(Theme.warn)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(28)
                .padding(.top, 72)
            }

            // One way out. Big enough to hit without looking.
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: Theme.minTarget + 8, height: Theme.minTarget + 8)
                    .background(Color.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(PressStyle())
            .padding(16)
            .accessibilityLabel("Close")
        }
        .preferredColorScheme(.dark)
        // Keep the screen awake while it's being read. Nothing here times out.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

#if DEBUG
#Preview {
    ShowView().environmentObject(SessionStore.preview())
}
#endif
