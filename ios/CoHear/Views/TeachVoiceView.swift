import SwiftUI
import UIKit

/// Record phrases so CoHear can learn this person's voice.
///
/// Same accessibility rules as the rest of the app: 64pt targets, no gestures,
/// nothing times out, one big button does the main thing. Record -> listen back
/// -> Keep or Redo. The phrase in front of you is the only thing to read.
struct TeachVoiceView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var store = VoiceSamples()

    @State private var newPhrase = ""
    @State private var shareURL: URL?
    @State private var errorText: String?
    @State private var confirmingDeleteAll = false
    @State private var showingRecordings = false
    @State private var tooShort = false
    @FocusState private var typing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                intro
                progress
                promptCard
                controls
                addPhrase
                recordingsSection
                exportSection
            }
            .padding(Theme.spacing)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle("Teach CoHear your voice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if session.isListening { session.stopListening() } }
        .onDisappear { store.stopPlayback(); if store.phase == .recording { store.stopRecording() } }
        .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
        .alert("Something went wrong", isPresented: .constant(errorText != nil)) {
            Button("OK") { errorText = nil }
        } message: { Text(errorText ?? "") }
        .confirmationDialog("Delete every recording?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) { store.deleteAll() }
            Button("Keep them", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Everyone's speech has its own patterns. When CoHear hears yours, it can learn them — the way family learns to understand you.")
                .font(Theme.label())
            Text("Read each phrase out loud, the way you normally talk. Don't try to speak more clearly than usual. Two recordings of each phrase is ideal. Recordings stay on this phone until you choose to export them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Your first name (optional)", text: $store.speakerName)
                .font(Theme.label())
                .textInputAutocapitalization(.words)
                .padding(14)
                .frame(minHeight: Theme.minTarget)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                .focused($typing)
        }
    }

    private var progress: some View {
        HStack(spacing: 12) {
            stat("\(store.samples.count)", "recordings")
            stat("\(store.phrasesDone)", "phrases done")
            stat(String(format: "%.1f", store.totalMinutes), "minutes")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Theme.brand)
            Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Say this").font(Theme.label()).foregroundStyle(.secondary)
                Spacer()
                let t = store.takes(for: store.currentPhrase)
                Text(t == 0 ? "not recorded yet" : "recorded \(t)×")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(t >= VoiceSamples.targetTakes ? Theme.live : .secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
            Text(store.currentPhrase)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            HStack(spacing: 12) {
                PillButton(title: "Back", systemImage: "chevron.left", tint: Theme.blue, filled: false,
                           enabled: store.phase == .idle) { store.previous() }
                PillButton(title: "Skip", systemImage: "chevron.right", tint: Theme.blue, filled: false,
                           enabled: store.phase == .idle) { store.next() }
            }
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private var controls: some View {
        switch store.phase {
        case .idle, .recording:
            VStack(spacing: 10) {
                RecordButton(recording: store.phase == .recording, level: store.level) {
                    if store.phase == .recording {
                        store.stopRecording()
                    } else {
                        tooShort = false
                        do { try store.startRecording() } catch { errorText = error.localizedDescription }
                    }
                }
                .frame(maxWidth: .infinity)
                if tooShort {
                    Label("That was too short to use — try again.", systemImage: "exclamationmark.circle")
                        .font(Theme.label()).foregroundStyle(Theme.warn)
                }
            }
        case .review, .playing:
            VStack(spacing: 12) {
                PillButton(title: store.phase == .playing ? "Stop" : "Listen back",
                           systemImage: store.phase == .playing ? "stop.fill" : "play.fill",
                           tint: Theme.blue, filled: false) {
                    store.phase == .playing ? store.stopPlayback() : store.playPending()
                }
                HStack(spacing: 12) {
                    PillButton(title: "Redo", systemImage: "arrow.counterclockwise",
                               tint: Theme.stop, filled: false) { store.discardPending() }
                    PillButton(title: "Keep", systemImage: "checkmark", tint: Theme.teal, filled: true) {
                        tooShort = !store.keep()
                    }
                }
            }
        }
    }

    private var addPhrase: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add your own").font(Theme.label())
            Text("Names, places, and things you say every day help the most.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                TextField("e.g. Can we call Grandma", text: $newPhrase)
                    .font(Theme.label())
                    .padding(14)
                    .frame(minHeight: Theme.minTarget)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit { commitPhrase() }
                Button(action: commitPhrase) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: Theme.minTarget, height: Theme.minTarget)
                        .background(Circle().fill(Theme.teal))
                }
                .buttonStyle(PressStyle())
                .disabled(newPhrase.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add phrase")
            }
        }
    }

    private func commitPhrase() {
        store.addPhrase(newPhrase)
        newPhrase = ""
        typing = false
    }

    private var recordingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { showingRecordings.toggle() } label: {
                HStack {
                    Text("Your recordings (\(store.samples.count))").font(Theme.label())
                    Spacer()
                    Image(systemName: showingRecordings ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(.primary)
                .frame(minHeight: Theme.minTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showingRecordings {
                ForEach(store.samples.reversed()) { s in
                    HStack(spacing: 10) {
                        Button { store.play(s) } label: {
                            Image(systemName: "play.circle.fill").font(.system(size: 30))
                                .foregroundStyle(Theme.blue)
                                .frame(width: Theme.minTarget, height: Theme.minTarget)
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel("Play \(s.text)")
                        Text(s.text).font(.body).lineLimit(2)
                        Spacer()
                        Button { store.delete(s) } label: {
                            Image(systemName: "trash").font(.system(size: 20))
                                .foregroundStyle(Theme.stop)
                                .frame(width: Theme.minTarget, height: Theme.minTarget)
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel("Delete \(s.text)")
                    }
                    .padding(.horizontal, 6)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                }
                if !store.samples.isEmpty {
                    PillButton(title: "Delete all recordings", systemImage: "trash",
                               tint: Theme.stop, filled: false) { confirmingDeleteAll = true }
                }
            }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Build your personal model").font(Theme.label())
            Text("Export sends the recordings wherever you choose — for example AirDrop to the computer that builds your model. Nothing is sent automatically, and CoHear has no server. About 100 recordings (roughly 10 minutes) is a good first batch.")
                .font(.subheadline).foregroundStyle(.secondary)
            PillButton(title: "Export recordings", systemImage: "square.and.arrow.up",
                       tint: Theme.blue, filled: true, enabled: !store.samples.isEmpty) {
                do { shareURL = try store.exportZip() } catch { errorText = error.localizedDescription }
            }
            if PersonalModel.isInstalled {
                Label("A personal model is installed. Pick it in Settings → Speech model.",
                      systemImage: "checkmark.seal.fill")
                    .font(.subheadline).foregroundStyle(Theme.live)
            }
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Components

/// Big round record button with a live level ring, matching the home screen.
private struct RecordButton: View {
    let recording: Bool
    let level: Float
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(recording ? max(0.02, level) : 0))
                    .stroke(Theme.live, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.06), value: level)
                Circle()
                    .fill(recording ? AnyShapeStyle(Theme.stop) : AnyShapeStyle(Theme.brand))
                    .padding(12)
                VStack(spacing: 6) {
                    Image(systemName: recording ? "stop.fill" : "mic.fill").font(.system(size: 40, weight: .bold))
                    Text(recording ? "Stop" : "Record").font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
            }
            .frame(width: 150, height: 150)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(recording ? "Stop recording" : "Record this phrase")
    }
}

/// System share sheet (AirDrop, Files, Mail…).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#if DEBUG
#Preview {
    NavigationStack { TeachVoiceView() }.environmentObject(SessionStore.preview())
}
#endif
