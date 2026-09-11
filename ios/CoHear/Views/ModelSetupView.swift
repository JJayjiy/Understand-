import SwiftUI

/// First launch: the speech model downloads once (~500 MB), then it's cached
/// forever. This is the only network request the app ever makes, and it says so.
///
/// Shown with real progress because a blank screen for two minutes on first
/// open is how people — and App Store reviewers — decide an app is broken.
struct ModelSetupView: View {
    let state: SessionStore.ModelState
    let message: String?
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Setting up CoHear")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            switch state {
            case .downloading(let p):
                VStack(spacing: 12) {
                    ProgressView(value: p)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 320)
                    Text("Downloading the speech model — \(Int(p * 100))%")
                        .font(Theme.label())
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            case .loading, .notLoaded:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Getting ready…")
                        .font(Theme.label())
                        .foregroundStyle(.secondary)
                }
            case .failed:
                VStack(spacing: 16) {
                    Text(message ?? "Something went wrong.")
                        .font(Theme.label())
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    BigButton(title: "Try again", systemImage: "arrow.clockwise") { retry() }
                        .frame(maxWidth: 320)
                }
            case .ready:
                EmptyView()
            }

            Text("This happens once. After it's done, everything runs on your phone — your voice never leaves it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Spacer()
            Spacer()
        }
        .padding(28)
    }
}
