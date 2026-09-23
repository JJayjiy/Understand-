import SwiftUI

/// The main screen. What you've said above, one hero button below.
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
        ZStack {
            Theme.canvas.ignoresSafeArea()

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
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showingShow) { ShowView() }
        .sheet(item: $editing) { u in EditView(utterance: u) }
        .task { await session.loadModelIfNeeded() }
    }

    // MARK: - Layout

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            transcript
            controls
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.brand)
                Text("CoHear").font(Theme.wordmark())
            }
            Spacer()
            statusPill
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: Theme.minTarget, height: Theme.minTarget)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, Theme.spacing)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusPill: some View {
        if session.isListening {
            StatusPill(text: session.hearingSpeech ? "Hearing you" : "Listening",
                       color: session.hearingSpeech ? Theme.live : Theme.blue,
                       active: true)
        } else if session.isTranscribing {
            StatusPill(text: "Working", color: Theme.teal, active: true)
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if session.utterances.isEmpty {
                        emptyState
                    }
                    ForEach(Array(session.utterances.enumerated()), id: \.element.id) { i, u in
                        UtteranceRow(
                            utterance: u,
                            scale: session.textScale,
                            isLatest: i == session.utterances.count - 1,
                            filtering: session.filterOtherVoices,
                            onEdit: { editing = u },
                            onClaim: { session.setOwnVoice(u.id, isOwn: true) }
                        )
                        .id(u.id)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if !session.statusMessage.isEmpty && !session.isListening {
                        Label(session.statusMessage, systemImage: "info.circle")
                            .font(Theme.label())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, Theme.spacing)
                .padding(.top, 12)
                .animation(.spring(duration: 0.35), value: session.utterances.count)
            }
            .onChange(of: session.utterances.count) { _, _ in
                if let last = session.utterances.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Say something.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.brand)
            Text("Tap Listen, talk, and pause. What you said shows up here — just for you — until you decide to show it.")
                .font(Theme.body(session.textScale))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 36)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack(spacing: 18) {
            // Show and Speak are always present — disabled when empty — so the
            // layout never jumps. Stable targets matter for a hand that can't aim.
            HStack(spacing: 12) {
                PillButton(title: "Show", systemImage: "rectangle.portrait.and.arrow.forward",
                           tint: Theme.teal, filled: true,
                           enabled: !session.visibleUtterances.isEmpty) {
                    showingShow = true
                }
                PillButton(title: session.speaker.isSpeaking ? "Stop" : "Speak",
                           systemImage: session.speaker.isSpeaking ? "stop.fill" : "speaker.wave.2.fill",
                           tint: Theme.blue, filled: false,
                           enabled: !session.visibleUtterances.isEmpty || session.speaker.isSpeaking) {
                    if session.speaker.isSpeaking { session.speaker.stop() }
                    else { session.speaker.speak(session.fullText) }
                }
            }

            HeroButton(listening: session.isListening,
                       level: session.level,
                       hearing: session.hearingSpeech) {
                if session.isListening { session.stopListening() }
                else { Task { await session.startListening() } }
            }
            .padding(.bottom, 6)
        }
        .padding(.horizontal, Theme.spacing)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(
            Theme.canvas
                .overlay(alignment: .top) {
                    LinearGradient(colors: [Color.primary.opacity(0.06), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 12)
                }
        )
    }
}

// MARK: - Row

struct UtteranceRow: View {
    let utterance: Utterance
    let scale: Double
    let isLatest: Bool
    let filtering: Bool
    let onEdit: () -> Void
    let onClaim: () -> Void

    private var dimmed: Bool { filtering && utterance.voice == .other }
    private var unsure: Bool { filtering && utterance.voice == .uncertain }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(utterance.text)
                        .font(isLatest && !dimmed ? Theme.latest(scale) : Theme.body(scale))
                        .foregroundStyle(dimmed ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let point = utterance.point, !point.isEmpty,
                       utterance.edited == nil, !dimmed {
                        Text(point)
                            .font(Theme.label())
                            .foregroundStyle(Theme.teal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())

            if dimmed || unsure {
                Button(action: onClaim) {
                    Label("This was me", systemImage: "person.fill.checkmark")
                        .font(Theme.label())
                        .foregroundStyle(Theme.blue)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                        .background(Capsule().fill(Theme.blue.opacity(dimmed ? 0.14 : 0.08)))
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(dimmed ? Theme.card.opacity(0.5) : Theme.card)
                .shadow(color: .black.opacity(isLatest && !dimmed ? 0.08 : 0.03),
                        radius: isLatest ? 12 : 4, y: isLatest ? 4 : 1)
        )
        .overlay(alignment: .leading) {
            if isLatest && !dimmed {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.brand)
                    .frame(width: 5)
                    .padding(.vertical, 14)
                    .padding(.leading, 6)
            }
        }
        .overlay(alignment: .topTrailing) {
            if dimmed || unsure {
                Text(dimmed ? "not you" : "not sure")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                    .padding(12)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(dimmed ? "Someone else: \(utterance.text)" : utterance.text)
    }
}

#if DEBUG
#Preview("Home") {
    RootView().environmentObject(SessionStore.preview())
}
#Preview("Home · listening") {
    RootView().environmentObject(SessionStore.preview(listening: true))
}
#Preview("Home · empty") {
    RootView().environmentObject(SessionStore.preview(empty: true))
}
#Preview("Home · dark") {
    RootView().environmentObject(SessionStore.preview()).preferredColorScheme(.dark)
}
#endif
