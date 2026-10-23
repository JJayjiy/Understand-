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

            if !session.hasOnboarded {
                WelcomeView()
                    .transition(.opacity)
            } else {
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
        }
        .animation(.easeInOut(duration: 0.35), value: session.hasOnboarded)
        .sheet(isPresented: $showingSettings) { SettingsView().environmentObject(session) }
        .fullScreenCover(isPresented: $showingShow) { ShowView().environmentObject(session) }
        .sheet(item: $editing) { u in EditView(utterance: u).environmentObject(session) }
        // The first download waits for the welcome screens, so it fetches the
        // model for the language the user picks there.
        .task { if session.hasOnboarded { await session.loadModelIfNeeded() } }
    }

    // MARK: - Layout

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            modeSwitch
            switch session.homeMode {
            case .talk:
                transcript
                controls
            case .phrases:
                // AAC-style board: tap a phrase, it's said out loud at once.
                QuickPhrasesView()
                    .padding(.top, 12)
            }
        }
        // Rebuild everything when the language changes, so child views that
        // don't observe the store (buttons, pills) pick up the new strings.
        .id(session.language)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.brand)
                VStack(alignment: .leading, spacing: 0) {
                    Text("CoHear").font(Theme.wordmark()).lineLimit(1).fixedSize()
                    // Which model is listening, always visible: nobody should
                    // mistake stock Whisper's output for their personal model.
                    Button { showingSettings = true } label: {
                        Text(session.modelChoice.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Speech model: ", "语音模型：") + session.modelChoice.title)
                }
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
            .accessibilityLabel(L("Settings", "设置"))
        }
        .padding(.horizontal, Theme.spacing)
        .padding(.top, 8)
    }

    /// Two big tabs: speak and have it written down, or tap ready-made phrases.
    private var modeSwitch: some View {
        HStack(spacing: 8) {
            modeTab(.talk, L("Talk", "说话"), "waveform")
            modeTab(.phrases, L("Phrases", "常用语"), "square.grid.2x2.fill")
        }
        .padding(5)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .padding(.horizontal, Theme.spacing)
        .padding(.top, 8)
    }

    private func modeTab(_ mode: SessionStore.HomeMode, _ title: String, _ icon: String) -> some View {
        let selected = session.homeMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { session.setHomeMode(mode) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(title).font(.system(size: 20, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selected ? .white : .primary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(selected ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.clear)))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var statusPill: some View {
        if session.isListening {
            StatusPill(text: session.hearingSpeech ? L("Hearing you", "听到了") : L("Listening", "正在听"),
                       color: session.hearingSpeech ? Theme.live : Theme.blue,
                       active: true)
        } else if session.isTranscribing {
            StatusPill(text: L("Working", "识别中"), color: Theme.teal, active: true)
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
                            showConfidence: session.showConfidence,
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
        VStack(alignment: .leading, spacing: 18) {
            Text(L("Say something.", "说点什么吧。"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.brand)
            VStack(alignment: .leading, spacing: 14) {
                emptyStep(1, L("Tap Listen and talk.", "点“听”，然后说话。"))
                emptyStep(2, L("Pause. Your words show up here, just for you.", "停一下。你的话会出现在这里，只有你能看到。"))
                emptyStep(3, L("Tap Show or Speak to share them.", "点“展示”或“朗读”分享给别人。"))
            }
            Text(L("Hard to get the words out? Switch to Phrases: tap one and it's said out loud, or type your own.",
                   "说不出来？切换到“常用语”：点一下就会读出来，也可以自己打字。"))
                .font(Theme.label())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(Theme.card))
        .padding(.top, 24)
        .accessibilityElement(children: .combine)
    }

    private func emptyStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(n)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.brand))
            Text(text)
                .font(Theme.body(min(session.textScale, 1.3)))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controls: some View {
        VStack(spacing: 18) {
            // Show and Speak are always present — disabled when empty — so the
            // layout never jumps. Stable targets matter for a hand that can't aim.
            HStack(spacing: 12) {
                PillButton(title: L("Show", "展示"), systemImage: "rectangle.portrait.and.arrow.forward",
                           tint: Theme.teal, filled: true,
                           enabled: !session.visibleUtterances.isEmpty) {
                    showingShow = true
                }
                PillButton(title: session.speaker.isSpeaking ? L("Stop", "停止") : L("Speak", "朗读"),
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
    var showConfidence: Bool = true
    let onEdit: () -> Void
    let onClaim: () -> Void

    private var dimmed: Bool { filtering && utterance.voice == .other }
    private var unsure: Bool { filtering && utterance.voice == .uncertain }
    /// The model was guessing. Shown, never hidden — the speaker may still
    /// recognise what they said — but marked so nobody reads it as fact.
    private var lowConf: Bool { showConfidence && utterance.confidence == .low }
    private var midConf: Bool { showConfidence && utterance.confidence == .medium }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(utterance.text)
                        .font(isLatest && !dimmed ? Theme.latest(scale) : Theme.body(scale))
                        .foregroundStyle(dimmed || lowConf ? .secondary : .primary)
                        .italic(lowConf)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if lowConf && !dimmed {
                        Label(L("Not sure it heard this right — tap to fix", "可能没听准，点这里修改"), systemImage: "questionmark.circle")
                            .font(Theme.label())
                            .foregroundStyle(Theme.warn)
                    }
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
                    Label(L("This was me", "这是我说的"), systemImage: "person.fill.checkmark")
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
            if lowConf && !dimmed {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.warn)
                    .frame(width: 5)
                    .padding(.vertical, 14)
                    .padding(.leading, 6)
            } else if isLatest && !dimmed {
                RoundedRectangle(cornerRadius: 3)
                    .fill(midConf ? AnyShapeStyle(Theme.warn.opacity(0.6)) : AnyShapeStyle(Theme.brand))
                    .frame(width: 5)
                    .padding(.vertical, 14)
                    .padding(.leading, 6)
            }
        }
        .overlay(alignment: .topTrailing) {
            if dimmed || unsure {
                Text(dimmed ? L("not you", "不是你") : L("not your voice?", "不是你的声音？"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                    .padding(12)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(dimmed ? L("Someone else: ", "别人说的：") + utterance.text
                            : lowConf ? L("Uncertain: ", "不确定：") + utterance.text : utterance.text)
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
