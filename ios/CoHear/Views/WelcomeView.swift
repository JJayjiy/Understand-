import SwiftUI

/// First launch: three short screens, then straight into the app.
///
/// 1. Pick a language (English / 中文), so everything after is readable.
/// 2. How it works: talk, check, share. Plus the fallbacks (Phrases, Type).
/// 3. The promises: on this phone only, honest about mistakes.
///
/// No swiping required: every step has a big Next button. The speech model
/// download starts only after "Get started", for the language picked here.
struct WelcomeView: View {
    @EnvironmentObject var session: SessionStore
    @State private var step = 0

    private let lastStep = 2

    var body: some View {
        VStack(spacing: 0) {
            dots
                .padding(.top, 20)

            ScrollView {
                Group {
                    switch step {
                    case 0: languagePage
                    case 1: howPage
                    default: promisePage
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .opacity))
                .id(step)
            }

            VStack(spacing: 10) {
                PillButton(title: step == lastStep ? L("Get started", "开始使用") : L("Next", "下一步"),
                           systemImage: step == lastStep ? "checkmark" : "arrow.right",
                           tint: Theme.blue, filled: true) {
                    if step == lastStep {
                        session.finishOnboarding()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
                    }
                }
                if step > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { step -= 1 }
                    } label: {
                        Text(L("Back", "返回"))
                            .font(Theme.label())
                            .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Theme.canvas.ignoresSafeArea())
    }

    // MARK: - Pages

    private var languagePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            logo
            Text("CoHear")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.brand)
            Text(L("Facilitating coherent speech.", "让表达更连贯。"))
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            // Bilingual on purpose: whoever opens the app can read this line.
            Text("Choose your language · 选择语言")
                .font(Theme.label())
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            ForEach(AppLanguage.allCases) { lang in
                languageButton(lang)
            }
        }
    }

    private func languageButton(_ lang: AppLanguage) -> some View {
        let selected = session.language == lang
        return Button {
            Task { await session.setLanguage(lang) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(selected ? Theme.teal : .secondary)
                Text(lang.nativeName)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selected ? Theme.teal.opacity(0.12) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(selected ? Theme.teal : Color.primary.opacity(0.08), lineWidth: 2)
            )
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var howPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(L("How it works", "怎么用"))
                .font(.system(size: 36, weight: .bold, design: .rounded))
            stepRow(1, "waveform", Theme.blue,
                    L("Talk", "说话"),
                    L("Tap Listen and speak. CoHear writes down what you said.",
                      "点“听”，然后说话。CoHear 会把你说的话写下来。"))
            stepRow(2, "eye", Theme.teal,
                    L("Check", "检查"),
                    L("Only you see it first. Tap any line to fix it.",
                      "先只有你能看到。点任何一句都可以修改。"))
            stepRow(3, "rectangle.portrait.and.arrow.forward", Theme.live,
                    L("Share", "分享"),
                    L("Show it in big letters, or have the phone say it out loud.",
                      "用大字展示给别人看，或者让手机读出来。"))
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.warn)
                Text(L("Words not coming out? Switch to Phrases: tap one and the phone says it out loud. You can type your own, too.",
                       "说不出来的时候？切换到“常用语”：点一下，手机就会读出来。也可以自己打字。"))
                    .font(Theme.label())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Theme.warn.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var promisePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(L("Our promises", "我们的承诺"))
                .font(.system(size: 36, weight: .bold, design: .rounded))
            promiseRow("lock.fill", Theme.blue,
                       L("Your voice stays on this phone", "你的声音只留在这台手机上"),
                       L("No account, no server, no ads. Conversations are gone when you close the app.",
                         "不需要账号，没有服务器，没有广告。关闭 app 后对话就会清除。"))
            promiseRow("questionmark.circle.fill", Theme.warn,
                       L("Honest when it's unsure", "不确定时会告诉你"),
                       L("It will make mistakes. When it's guessing, it says so instead of pretending.",
                         "它会出错。在猜的时候，它会标出来，而不是假装听懂了。"))
            promiseRow("person.fill.checkmark", Theme.teal,
                       L("You're in control", "由你决定"),
                       L("Nothing is shown or spoken until you choose. CoHear never speaks for you.",
                         "你不点，就不会展示或朗读。CoHear 从不替你说话。"))
            promiseRow("arrow.down.circle.fill", Theme.live,
                       L("One download, then offline", "下载一次，之后离线可用"),
                       L("The speech model (about 500 MB) downloads once. Wi-Fi recommended.",
                         "语音模型（约 500 MB）只需下载一次。建议连接 Wi-Fi。"))
            Text(L("CoHear is a research tool, not a medical device.",
                   "CoHear 是研究工具，不是医疗设备。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Building blocks

    private var logo: some View {
        ZStack {
            Circle().fill(Theme.brand).frame(width: 96, height: 96)
                .shadow(color: Theme.blue.opacity(0.3), radius: 16, y: 6)
            Image(systemName: "waveform")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0...lastStep, id: \.self) { i in
                Capsule()
                    .fill(i == step ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.primary.opacity(0.15)))
                    .frame(width: i == step ? 28 : 10, height: 10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Step \(step + 1) of \(lastStep + 1)", "第 \(step + 1) 步，共 \(lastStep + 1) 步"))
    }

    private func stepRow(_ n: Int, _ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(tint.opacity(0.14)).frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(n). \(title)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(detail)
                    .font(Theme.label())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func promiseRow(_ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(Theme.label())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    WelcomeView().environmentObject(SessionStore.preview())
}
#endif
