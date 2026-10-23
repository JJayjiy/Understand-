import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false

    private func isFailed(_ s: SessionStore.ModelState) -> Bool {
        if case .failed = s { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            List {
                // Always bilingual, so anyone can find their language.
                Section {
                    Picker("Language / 语言", selection: Binding(
                        get: { session.language },
                        set: { new in Task { await session.setLanguage(new) } }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.nativeName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .frame(minHeight: Theme.minTarget)
                    .disabled(session.modelState != .ready && !isFailed(session.modelState))
                } header: {
                    Text("Language / 语言")
                } footer: {
                    Text(L("Changes the menus and the language CoHear listens for. English and Chinese use different speech models; switching may download one.",
                           "同时切换菜单语言和 CoHear 识别的语言。中英文使用不同的语音模型，切换时可能需要下载。"))
                }

                Section(L("Text size", "文字大小")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("The quick brown fox", "你好，很高兴见到你"))
                            .font(Theme.body(session.textScale))
                        Slider(value: $session.textScale, in: 0.8...2.2, step: 0.1)
                            .accessibilityLabel(L("Text size", "文字大小"))
                            .accessibilityValue("\(Int(session.textScale * 100))%")
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Toggle(isOn: $session.clarifyEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("Clarify", "整理")).font(Theme.label())
                            Text(L("Clean up what was heard and add a one-line summary. Runs on this phone.",
                                   "把听到的内容整理通顺，并加一句总结。在手机上运行。"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!session.clarifier.isAvailable)
                    .frame(minHeight: Theme.minTarget)

                    if let reason = session.clarifier.unavailableReason {
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(L("Clarify", "整理"))
                }

                Section {
                    Toggle(isOn: $session.filterOtherVoices) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("Only my voice", "只显示我的声音")).font(Theme.label())
                            Text(L("Dims lines that sound like someone else, and leaves them out of Show and Speak. Nothing is ever deleted — tap any line to correct it.",
                                   "像是别人说的句子会变淡，不会出现在“展示”和“朗读”里。不会删除任何内容，点任何一句都可以更正。"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: Theme.minTarget)

                    Text(L("This is a guess based on pitch and voice quality. It works best when the other person's voice is clearly different from yours, and it will sometimes be wrong.",
                           "这是根据音高和音色做的猜测。对方声音和你差别明显时最准，有时会判断错。"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(L("Other voices", "其他人的声音"))
                }

                if Features.teachVoice {
                Section {
                    NavigationLink {
                        TeachVoiceView()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(L("Teach CoHear your voice", "教 CoHear 认识你的声音"), systemImage: "waveform.badge.mic")
                                .font(Theme.label())
                            Text(PersonalModel.isInstalled
                                 ? (PersonalModel.summary ?? L("Personal model installed.", "已安装个人模型。"))
                                 : L("Record phrases so CoHear can learn how you speak.", "录几段话，让 CoHear 学习你说话的方式。"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(minHeight: Theme.minTarget)
                    }
                } header: {
                    Text(L("Your voice", "你的声音"))
                }
                }

                Section(L("This session", "本次对话")) {
                    Button(role: .destructive) { confirmingClear = true } label: {
                        Label(L("Clear everything said", "清除所有内容"), systemImage: "trash")
                            .font(Theme.label())
                            .frame(minHeight: Theme.minTarget)
                    }
                    .disabled(session.utterances.isEmpty)
                }

                Section(L("Privacy", "隐私")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L("Your voice never leaves this phone.", "你的声音不会离开这台手机。"), systemImage: "lock.fill")
                            .font(Theme.label())
                        Text(L("Speech recognition and Clarify both run on the device. CoHear has no server, no account, and no analytics. Conversations are not stored after you close the app. Recordings you make in Teach CoHear your voice stay on this phone until you delete or export them.",
                               "语音识别和“整理”都在手机上运行。CoHear 没有服务器、不需要账号、不做数据分析。关闭 app 后对话不会保存。你在“教 CoHear 认识你的声音”里的录音会一直留在手机上，直到你删除或导出。"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(L("The speech model is downloaded once from Hugging Face on first launch. That download is the only network request the app makes.",
                               "语音模型在第一次使用时从 Hugging Face 下载一次。这是 app 唯一的联网请求。"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    ForEach(Transcriber.ModelChoice.available) { choice in
                        Button {
                            guard choice != session.modelChoice else { return }
                            Task { await session.switchModel(to: choice) }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: choice == session.modelChoice ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(choice == session.modelChoice ? Theme.teal : .secondary)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(choice.title).font(Theme.label()).foregroundStyle(.primary)
                                    Text(choice.note).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(session.modelState != .ready && session.modelState != .notLoaded
                                  && !isFailed(session.modelState))
                    }
                    Text(L("Switching downloads the new model once, then it's cached. Same phone, same speaker, different model — that's the comparison worth making.",
                           "切换时会下载一次新模型，之后会保存在手机上。同一台手机、同一个人、不同模型，这样对比才有意义。"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(L("Speech model", "语音模型"))
                }

                Section {
                    Toggle(isOn: $session.showConfidence) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("Flag uncertain lines", "标出不确定的句子")).font(Theme.label())
                            Text(L("When the model was guessing, the line is marked so a reader knows not to trust it. Turn off to see raw output.",
                                   "模型在猜的时候会标出来，让读的人知道别全信。关掉后显示原始结果。"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: Theme.minTarget)
                } header: {
                    Text(L("Honesty", "诚实"))
                }

                Section(L("About", "关于")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("CoHear helps a listener understand you. It never speaks for you. What it hears is shown only to you until you choose to show it to someone else.",
                               "CoHear 帮助别人听懂你，但从不替你说话。它听到的内容只给你看，直到你决定给别人看。"))
                            .font(.subheadline)
                        Text(L("This is a research tool, not a medical device. It has not been clinically validated and should not be relied on where a mistake would matter — medical, legal, or financial decisions. It is wrong sometimes. Read what it wrote before you show it.",
                               "这是研究工具，不是医疗设备，没有经过临床验证。不要在出错会有严重后果的场合依赖它，比如医疗、法律或财务决定。它有时会出错，给别人看之前请先读一遍。"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Link(L("Research and source code", "研究和源代码"), destination: URL(string: "https://github.com/JJayjiy/Understand-")!)
                            .font(Theme.label())
                            .frame(minHeight: Theme.minTarget)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(L("Settings", "设置"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done", "完成")) { dismiss() }
                        .font(Theme.label())
                        .frame(minHeight: Theme.minTarget)
                }
            }
            .confirmationDialog(L("Clear everything from this session?", "清除本次对话的所有内容？"), isPresented: $confirmingClear,
                                titleVisibility: .visible) {
                Button(L("Clear", "清除"), role: .destructive) { session.clearAll() }
                Button(L("Keep it", "保留"), role: .cancel) {}
            }
        }
    }
}

#if DEBUG
#Preview {
    SettingsView().environmentObject(SessionStore.preview())
}
#endif

/// Features that are built but not yet shown to everyone.
///
/// teachVoice: "Teach CoHear your voice" (recording + export for a personal model).
/// Off for the 1.0 App Store submission so the review build matches the review
/// video exactly; turn on for TestFlight / a later version once it has been
/// tested end to end with real users.
enum Features {
    static let teachVoice = true   // ON for TestFlight builds; set false for App Store builds until 1.1
}
