import SwiftUI

/// The screen you turn around and point at someone.
///
/// Maximum text, nothing else. Readable across a table. This is the only place
/// the transcript is meant to be seen by anyone other than the speaker, and
/// the speaker got here by tapping Show — a deliberate act.
struct ShowView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                // fullText already excludes lines attributed to other voices —
                // what gets turned around and shown is the speaker's words only.
                Text(session.fullText)
                    .font(Theme.show(session.textScale))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(28)
                    .padding(.top, 56)
            }

            // One way out. Big enough to hit without looking.
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .bold))
                    .frame(width: Theme.minTarget + 8, height: Theme.minTarget + 8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("Close")
        }
        // Keep the screen awake while it's being read. Nothing here times out.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
