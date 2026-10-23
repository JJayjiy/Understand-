import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
    @State private var keepProblem: VoiceSamples.KeepResult?
    @State private var importingModel = false
    @State private var installedNote: String?
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
        .navigationTitle(L("Teach CoHear your voice", "教 CoHear 认识你的声音"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if session.isListening { session.stopListening() } }
        .onDisappear {
            store.stopPlayback(); session.speaker.stop()
            if store.phase == .recording { store.stopRecording() }
        }
        .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
        .alert(L("Something went wrong", "出了点问题"), isPresented: .constant(errorText != nil)) {
            Button(L("OK", "好")) { errorText = nil }
        } message: { Text(errorText ?? "") }
        .confirmationDialog(L("Delete every recording?", "删除所有录音？"), isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button(L("Delete all", "全部删除"), role: .destructive) { store.deleteAll() }
            Button(L("Keep them", "保留"), role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Everyone's speech has its own patterns. When CoHear hears yours, it can learn them — the way family learns to understand you.",
                   "每个人说话都有自己的特点。CoHear 听过你的声音后就能学会，就像家人慢慢能听懂你一样。"))
                .font(Theme.label())
            Text(L("Quick start: say \(VoiceSamples.quickStart.count) short everyday phrases, the way you normally talk. Hard to read? Tap Hear it and say it back. Together they contain every sound in English — about 5 minutes. Don't try to speak more clearly than usual, and take breaks. Recordings stay on this phone until you choose to export them.",
                   "快速开始：用平时说话的方式，说 \(VoiceSamples.quickStart.count) 句日常短句。看字有困难？点“听一遍”，跟着说就行。这些短句包含了普通话所有的声母、韵母和声调，大约 5 分钟。不用刻意说得更清楚，累了就休息。录音会留在手机上，直到你选择导出。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(L("Your first name (optional)", "你的名字（可不填，建议用拼音）"), text: $store.speakerName)
                .font(Theme.label())
                .textInputAutocapitalization(.words)
                .padding(14)
                .frame(minHeight: Theme.minTarget)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                .focused($typing)
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                stat("\(store.quickStartDone)/\(VoiceSamples.quickStart.count)", L("quick start", "快速开始"))
                stat("\(store.samples.count)", L("recordings", "段录音"))
                stat(String(format: "%.1f", store.totalMinutes), L("minutes", "分钟"))
            }
            if store.quickStartComplete {
                Label(L("Quick start done. You can export now, or keep going — every extra recording makes it more accurate.",
                        "快速开始完成了。现在可以导出，也可以继续录，多录一段就更准一点。"),
                      systemImage: "checkmark.circle.fill")
                    .font(.subheadline).foregroundStyle(Theme.live)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Short phrases get very large type; passages shrink so they still fit.
    /// Chinese characters are about twice as wide as letters.
    private var phraseFontSize: CGFloat {
        let n = Double(store.currentPhrase.count) * (session.language == .zh ? 2 : 1)
        return n <= 30 ? 44 : n <= 60 ? 34 : 27
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
                Text(store.isQuickStartPhrase ? L("Quick start", "快速开始") : L("Keep improving", "继续提升"))
                    .font(Theme.label()).foregroundStyle(.secondary)
                Spacer()
                let t = store.takes(for: store.currentPhrase)
                Text(t == 0 ? L("not recorded yet", "还没录") : L("recorded ✓", "已录 ✓"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(t >= VoiceSamples.targetTakes ? Theme.live : .secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
            Text(store.currentPhrase)
                .font(.system(size: phraseFontSize, weight: .semibold, design: .rounded))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            // Reading is the hard part for many people (stroke, low vision,
            // English as a second language). Hearing it and repeating works
            // just as well for training: what matters is that the words match.
            PillButton(title: session.speaker.isSpeaking ? L("Stop", "停止") : L("Hear it", "听一遍"),
                       systemImage: session.speaker.isSpeaking ? "stop.fill" : "speaker.wave.2.fill",
                       tint: Theme.teal, filled: false, enabled: store.phase == .idle) {
                if session.speaker.isSpeaking { session.speaker.stop() }
                else { session.speaker.speak(store.currentPhrase) }
            }
            HStack(spacing: 12) {
                PillButton(title: L("Back", "上一句"), systemImage: "chevron.left", tint: Theme.blue, filled: false,
                           enabled: store.phase == .idle) { store.previous() }
                PillButton(title: L("Skip", "跳过"), systemImage: "chevron.right", tint: Theme.blue, filled: false,
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
                        session.speaker.stop()
                        keepProblem = nil
                        do { try store.startRecording() } catch { errorText = error.localizedDescription }
                    }
                }
                .frame(maxWidth: .infinity)
                if let problem = keepProblem {
                    Label(problem == .tooLong
                          ? L("That was over 30 seconds — the model can only learn from 30 seconds at a time. Tap Skip for a shorter one.",
                              "超过 30 秒了，模型一次最多只能学 30 秒。点“跳过”换一段短的，或者把这段分成两半加到“自己的话”里。")
                          : L("That was too short to use — try again.", "太短了，请再录一次。"),
                          systemImage: "exclamationmark.circle")
                        .font(Theme.label()).foregroundStyle(Theme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .review, .playing:
            VStack(spacing: 12) {
                PillButton(title: store.phase == .playing ? L("Stop", "停止") : L("Listen back", "回放"),
                           systemImage: store.phase == .playing ? "stop.fill" : "play.fill",
                           tint: Theme.blue, filled: false) {
                    store.phase == .playing ? store.stopPlayback() : store.playPending()
                }
                HStack(spacing: 12) {
                    PillButton(title: L("Redo", "重录"), systemImage: "arrow.counterclockwise",
                               tint: Theme.stop, filled: false) { store.discardPending() }
                    PillButton(title: L("Keep", "保留"), systemImage: "checkmark", tint: Theme.teal, filled: true) {
                        let r = store.keep()
                        keepProblem = (r == .kept) ? nil : r
                    }
                }
            }
        }
    }

    private var addPhrase: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Add your own", "加上你自己的话")).font(Theme.label())
            Text(L("Names, places, and things you say every day help the most.", "家人名字、地名和每天常说的话最有用。"))
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                TextField(L("e.g. Can we call Grandma", "例如：给奶奶打个电话"), text: $newPhrase)
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
                .accessibilityLabel(L("Add phrase", "添加"))
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
                    Text(L("Your recordings", "你的录音") + " (\(store.samples.count))").font(Theme.label())
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
                        .accessibilityLabel(L("Play ", "播放 ") + s.text)
                        Text(s.text).font(.body).lineLimit(2)
                        Spacer()
                        Button { store.delete(s) } label: {
                            Image(systemName: "trash").font(.system(size: 20))
                                .foregroundStyle(Theme.stop)
                                .frame(width: Theme.minTarget, height: Theme.minTarget)
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(L("Delete ", "删除 ") + s.text)
                    }
                    .padding(.horizontal, 6)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                }
                if !store.samples.isEmpty {
                    PillButton(title: L("Delete all recordings", "删除所有录音"), systemImage: "trash",
                               tint: Theme.stop, filled: false) { confirmingDeleteAll = true }
                }
            }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Build your personal model", "制作你的个人模型")).font(Theme.label())
            Text(L("Export sends the recordings wherever you choose — AirDrop, email, or Google Drive — to whoever builds your model. Nothing is sent automatically, and CoHear has no server. The 5 quick-start passages are enough for a first model; more recordings make it better.",
                   "导出会把录音发送到你选择的地方（隔空投送、邮件或网盘），交给帮你制作模型的人。不会自动发送，CoHear 也没有服务器。5 段快速开始就够做第一个模型，录得越多越好。"))
                .font(.subheadline).foregroundStyle(.secondary)
            PillButton(title: L("Export recordings", "导出录音"), systemImage: "square.and.arrow.up",
                       tint: Theme.blue, filled: true, enabled: !store.samples.isEmpty) {
                do { shareURL = try store.exportZip() } catch { errorText = error.localizedDescription }
            }
            Text(L("Got your personal model back? Save it to the Files app, then install it here.",
                   "收到个人模型了？先存到“文件”app，再在这里安装。"))
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.top, 6)
            PillButton(title: PersonalModel.isInstalled ? L("Replace personal model", "替换个人模型") : L("Install personal model", "安装个人模型"),
                       systemImage: "square.and.arrow.down", tint: Theme.teal, filled: false) {
                importingModel = true
            }
            if let note = installedNote {
                Label(note, systemImage: "checkmark.seal.fill")
                    .font(.subheadline).foregroundStyle(Theme.live)
                    .fixedSize(horizontal: false, vertical: true)
            } else if PersonalModel.isInstalled {
                Label(L("A personal model is installed. Pick it in Settings → Speech model.",
                        "已安装个人模型（\(PersonalModel.language.nativeName)）。在 设置 → 语音模型 中选择它。"),
                      systemImage: "checkmark.seal.fill")
                    .font(.subheadline).foregroundStyle(Theme.live)
            }
        }
        .padding(.bottom, 24)
        .fileImporter(isPresented: $importingModel, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                do {
                    try PersonalModel.install(from: url)
                    let lang = (PersonalModel.installedLanguage ?? .en).nativeName
                    installedNote = L("Installed (\(lang)). Pick \"Your voice\" in Settings → Speech model while the app is in \(lang).",
                                      "安装好了（\(lang)）。把语言切换到\(lang)，然后在 设置 → 语音模型 中选“你的声音”。")
                } catch {
                    errorText = error.localizedDescription
                }
            case .failure(let error):
                errorText = error.localizedDescription
            }
        }
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
                    Text(recording ? L("Stop", "停止") : L("Record", "录音")).font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
            }
            .frame(width: 150, height: 150)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(recording ? L("Stop recording", "停止录音") : L("Record this phrase", "录这一段"))
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
