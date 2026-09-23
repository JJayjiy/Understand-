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
                VStack(alignment: .leading, spacing: 24) {
                    // fullText already excludes lines attributed to other voices —
                    // what gets turned around and shown is the speaker's words only.
                    Text(session.fullText)
                        .font(Theme.show(session.textScale))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
