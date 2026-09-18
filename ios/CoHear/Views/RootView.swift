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
                        UtteranceRow(
                            utterance: u,
                            scale: session.textScale,
                            filtering: session.filterOtherVoices,
                            onEdit: { editing = u },
                            onClaim: { session.setOwnVoice(u.id, isOwn: true) },
                            onDisown: { session.setOwnVoice(u.id, isOwn: false) }
                        )
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

            if session.isListening {
                LevelMeter(level: session.level, hearing: session.hearingSpeech)
            } else if !session.statusMessage.isEmpty {
                Label(session.statusMessage, systemImage: "info.circle")
                    .font(Theme.label())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Level meter

/// Shows the mic is live and whether it's hearing you.
///
/// This is not decoration. Without it, "the app didn't hear me" and "the app is
/// broken" look identical, and the person has no way to tell whether to speak
/// louder, move closer, or give up.
struct LevelMeter: View {
    let level: Float
    let hearing: Bool

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.20))
                    Capsule()
                        .fill(hearing ? Color.green : Color.secondary)
                        .frame(width: max(6, geo.size.width * CGFloat(level)))
                        .animation(.linear(duration: 0.05), value: level)
                }
            }
            .frame(height: 14)

            Text(hearing ? "Hearing you" : "Listening — speak up a little")
                .font(Theme.label())
                .foregroundStyle(hearing ? .green : .secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hearing ? "Hearing you" : "Listening, no speech detected")
    }
}

// MARK: - Row

struct UtteranceRow: View {
    let utterance: Utterance
    let scale: Double
    let filtering: Bool
    let onEdit: () -> Void
    let onClaim: () -> Void
    let onDisown: () -> Void

    /// Dimmed and excluded: only when clearly another voice.
    private var dimmed: Bool { filtering && utterance.voice == .other }
    /// Tagged but still shown: the classifier wasn't sure.
    private var unsure: Bool { filtering && utterance.voice == .uncertain }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(utterance.text)
                        .font(Theme.body(scale))
                        .foregroundStyle(dimmed ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let point = utterance.point, !point.isEmpty,
                       utterance.edited == nil, !dimmed {
                        Text(point)
                            .font(Theme.label())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            }
            .buttonStyle(.plain)

            // One tap to correct. Full-width, not an icon — this is the most
            // likely thing to be wrong, and fixing it must not require aim.
            //
            // Dimmed  → "This was me" (prominent; the speaker's words are hidden)
            // Unsure  → both options, quietly
            // Own     → "Someone else" only if the speaker hasn't already ruled
            if dimmed || unsure {
                Button(action: onClaim) {
                    Label("This was me", systemImage: "person.fill.checkmark")
                        .font(Theme.label())
                        .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                        .background(.tint.opacity(dimmed ? 0.18 : 0.08),
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            if !dimmed, filtering, !utterance.voiceConfirmedByUser {
                Button(action: onDisown) {
                    Label("Someone else said this", systemImage: "person.2")
                        .font(Theme.label())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            (dimmed ? Color.secondary.opacity(0.05) : Color.secondary.opacity(0.10)),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(alignment: .topTrailing) {
            if dimmed || unsure {
                Text(dimmed ? "not you" : "not sure")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.secondary.opacity(0.15), in: Capsule())
                    .padding(10)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(dimmed ? "Someone else: \(utterance.text)" : utterance.text)
    }
}
