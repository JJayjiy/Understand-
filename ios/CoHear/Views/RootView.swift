import SwiftUI

/// The main screen. Transcript on top, one enormous button on the bottom.
///
/// Everything the speaker said this session lives here, private to this screen,
/// until they choose to Show it or Speak it. That's the design rule the whole
/// app hangs on: nothing is shared until the speaker shares it.
struct RootView: View {
    @EnvironmentObject var session: SessionStore
    @State private var showingShow = false
    @State private var showingSettings = false
    @State private var editing: Utterance?

    var body: some View {
        NavigationStack {
            Group {
                switch session.modelState {
                case .ready:
                    mainContent
                case .failed(let msg):
                    ModelSetupView(state: session.modelState, message: msg) {
                        Task { await session.loadModelIfNeeded() }
                    }
                default:
                    ModelSetupView(state: session.modelState, message: nil) {
                        Task { await session.loadModelIfNeeded() }
                    }
                }
            }
            .navigationTitle("CoHear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: Theme.minTarget, height: Theme.minTarget)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .fullScreenCover(isPresented: $showingShow) { ShowView() }
            .sheet(item: $editing) { u in EditView(utterance: u) }
        }
        .task { await session.loadModelIfNeeded() }
    }

    // MARK: - Main

    private var mainContent: some View {
        VStack(spacing: 0) {
            transcript
            Divider()
            controls
                .padding(Theme.spacing)
                .background(.bar)
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.spacing) {
                    if session.utterances.isEmpty {
                        emptyState
                    }
                    ForEach(session.utterances) { u in
                        UtteranceRow(utterance: u, scale: session.textScale) {
                            editing = u
                        }
                        .id(u.id)
                    }
                    if session.isTranscribing {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Working…").font(Theme.label()).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(Theme.spacing)
            }
            .onChange(of: session.utterances.count) { _, _ in
                if let last = session.utterances.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tap Listen and start talking.")
                .font(Theme.body(session.textScale))
            Text("What you say shows up here, just for you. Nothing is shared until you tap Show.")
                .font(Theme.label())
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack(spacing: Theme.spacing) {
            if !session.utterances.isEmpty {
                HStack(spacing: Theme.spacing) {
                    BigButton(title: "Show", systemImage: "rectangle.expand.vertical", tint: .green) {
                        showingShow = true
                    }
                    BigButton(title: session.speaker.isSpeaking ? "Stop" : "Speak",
                              systemImage: session.speaker.isSpeaking ? "stop.fill" : "speaker.wave.2.fill",
                              tint: .indigo) {
                        if session.speaker.isSpeaking {
                            session.speaker.stop()
                        } else {
                            session.speaker.speak(session.fullText)
                        }
                    }
                }
            }

            BigButton(
                title: session.isListening ? "Stop" : "Listen",
                systemImage: session.isListening ? "stop.circle.fill" : "mic.circle.fill",
                tint: session.isListening ? .red : .accentColor,
                height: Theme.primaryButtonHeight
            ) {
                if session.isListening {
                    session.stopListening()
                } else {
                    Task { await session.startListening() }
                }
            }
            .accessibilityHint(session.isListening ? "Stops listening" : "Starts listening. Speak, then pause.")

            if !session.statusMessage.isEmpty {
                Label(session.statusMessage, systemImage: session.isListening ? "waveform" : "info.circle")
                    .font(Theme.label())
                    .foregroundStyle(session.isListening ? .red : .secondary)
                    .symbolEffect(.variableColor.iterative, isActive: session.isListening)
            }
        }
    }
}

// MARK: - Row

struct UtteranceRow: View {
    let utterance: Utterance
    let scale: Double
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                Text(utterance.text)
                    .font(Theme.body(scale))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let point = utterance.point, !point.isEmpty, utterance.edited == nil {
                    Text(point)
                        .font(Theme.label())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            .padding(14)
            .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(utterance.text)
        .accessibilityHint("Tap to edit")
    }
}
