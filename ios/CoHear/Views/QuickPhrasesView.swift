import SwiftUI

/// The Phrases board: tap a phrase and the phone says it out loud, right away.
///
/// This is the AAC side of CoHear. Speech recognition will sometimes fail:
/// a bad day, a noisy room, a word the model has never heard. When it does,
/// the person should never be stuck. The things people most need to say fast
/// ("I need help", "Water, please", "Yes", "No") are one tap from being heard.
///
/// Layout: a big display on top shows what was just said, in letters large
/// enough to read across a room (it grows once something has been said). The
/// board stays below, so the next phrase is always one tap away.
///
/// Same accessibility rules as the rest of the app: big targets, no gestures,
/// nothing times out.
struct QuickPhrasesView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var custom = CustomPhrases()

    @State private var category = QuickPhrases.defaultCategory
    @State private var said: String?
    @State private var editing = false
    @State private var adding = false
    @State private var typing = false
    @State private var newText = ""

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 12) {
                display
                    .frame(height: geo.size.height * (said == nil ? 0.26 : 0.5))
                categoryBar
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        if category == QuickPhrases.mineCategory {
                            mineTiles
                        } else {
                            ForEach(QuickPhrases.phrases(in: category)) { phraseTile($0) }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, Theme.spacing)
            .animation(.spring(duration: 0.35), value: said)
        }
        .sheet(isPresented: $typing) {
            TypeView { text in say(text) }.environmentObject(session)
        }
        .alert(L("Add a phrase", "添加常用语"), isPresented: $adding) {
            TextField(L("e.g. Where is Mei?", "例如：小美在哪儿？"), text: $newText)
            Button(L("Add", "添加")) { custom.add(newText); newText = "" }
            Button(L("Cancel", "取消"), role: .cancel) { newText = "" }
        } message: {
            Text(L("Names and things you say every day.", "家人的名字和每天常说的话。"))
        }
        // Keep the screen awake while someone reads the display.
        .onChange(of: said) { _, new in UIApplication.shared.isIdleTimerDisabled = (new != nil) }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            session.speaker.stop()
        }
    }

    private func say(_ text: String) {
        said = text
        session.speaker.speak(text)
    }

    // MARK: - Display

    /// What was just said, huge. Tap it to say it again.
    private var display: some View {
        ZStack(alignment: .topLeading) {
            Button {
                if let s = said { session.speaker.speak(s) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(Color(red: 0.05, green: 0.06, blue: 0.09))
                    if let s = said {
                        Text(s)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.3)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 44)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 34, weight: .semibold))
                            Text(L("Tap a phrase below.\nThe phone says it out loud.",
                                   "点下面的短句，\n手机会马上读出来。"))
                                .font(Theme.label())
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white.opacity(0.65))
                        .padding()
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if said != nil {
                        Label(session.speaker.isSpeaking ? L("Speaking", "朗读中") : L("Tap to repeat", "点一下再读"),
                              systemImage: session.speaker.isSpeaking ? "speaker.wave.3.fill" : "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .symbolEffect(.variableColor.iterative, isActive: session.speaker.isSpeaking)
                            .padding(16)
                    }
                }
            }
            .buttonStyle(PressStyle())
            .disabled(said == nil)
            .accessibilityLabel(said.map { L("Said: ", "已读：") + $0 } ?? L("Nothing said yet", "还没有读"))
            .accessibilityHint(said == nil ? "" : L("Says it again", "再读一遍"))

            if said != nil {
                Button {
                    session.speaker.stop()
                    said = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(PressStyle())
                .padding(10)
                .accessibilityLabel(L("Clear", "清除"))
            }
        }
    }

    // MARK: - Categories

    private var categoryBar: some View {
        HStack(spacing: 8) {
            ForEach(QuickPhrases.categories) { c in
                let selected = category == c.id
                Button {
                    category = c.id
                    editing = false
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: c.icon).font(.system(size: 18, weight: .semibold))
                        Text(c.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(selected ? .white : c.tint)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selected ? c.tint : c.tint.opacity(0.12))
                    )
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: - Tiles

    @ViewBuilder
    private var mineTiles: some View {
        actionTile(L("Type", "打字"), "keyboard.fill", Theme.blue) { typing = true }
        actionTile(L("Add phrase", "添加短句"), "plus", Theme.teal, dashed: true) { adding = true }
        ForEach(custom.items, id: \.self) { t in
            phraseTile(QuickPhrase(text: t, icon: "text.bubble.fill", tint: Theme.teal, custom: true))
        }
        if !custom.items.isEmpty {
            actionTile(editing ? L("Done", "完成") : L("Remove…", "删除…"),
                       editing ? "checkmark" : "minus.circle", Theme.stop) { editing.toggle() }
        }
    }

    private func phraseTile(_ p: QuickPhrase) -> some View {
        let removable = editing && p.custom
        return Button {
            if removable {
                custom.remove(p.text)
                if custom.items.isEmpty { editing = false }
            } else {
                say(p.text)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: removable ? "minus.circle.fill" : p.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(removable ? Theme.stop : p.tint)
                    .frame(width: 32)
                Text(p.text)
                    .font(.system(size: 20 * min(session.textScale, 1.3), weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(said == p.text ? p.tint.opacity(0.16) : Theme.card)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(p.tint.opacity(said == p.text ? 0.8 : 0.25), lineWidth: 1.5)
            )
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(removable ? L("Remove ", "删除 ") + p.text : p.text)
        .accessibilityHint(removable ? "" : L("Says it out loud", "读出来"))
    }

    private func actionTile(_ title: String, _ icon: String, _ tint: Color, dashed: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 32)
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(dashed ? Color.clear : tint.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(tint.opacity(0.5),
                                  style: StrokeStyle(lineWidth: 2, dash: dashed ? [8, 6] : []))
            )
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(title)
    }
}

// MARK: - Type instead

/// Type something that isn't on the board, then have the phone say it.
struct TypeView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let onSay: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextEditor(text: $text)
                    .font(Theme.latest(session.textScale))
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .focused($focused)
                    .accessibilityLabel(L("Type what you want to say", "输入你想说的话"))

                PillButton(title: L("Say it", "读出来"), systemImage: "speaker.wave.2.fill",
                           tint: Theme.blue, filled: true, enabled: !isEmpty) {
                    onSay(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
            }
            .padding(Theme.spacing)
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(L("Type it", "打字"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel", "取消")) { dismiss() }
                        .font(Theme.label())
                        .frame(minHeight: Theme.minTarget)
                }
            }
            .onAppear { focused = true }
        }
    }
}

// MARK: - Data

struct QuickPhrase: Identifiable {
    var id: String { text }
    let text: String
    let icon: String
    let tint: Color
    var custom = false
}

/// Built-in phrases: the things people most need to say fast. Drawn from
/// caregiver and message-banking lists (answers, needs, feelings).
enum QuickPhrases {
    struct Category: Identifiable {
        let id: String
        let title: String
        let icon: String
        let tint: Color
    }

    static let defaultCategory = "needs"
    static let mineCategory = "mine"

    static var categories: [Category] {
        [
            Category(id: "needs", title: L("Needs", "需要"), icon: "hand.raised.fill", tint: Theme.stop),
            Category(id: "answers", title: L("Answers", "回答"), icon: "checkmark.bubble.fill", tint: Theme.blue),
            Category(id: "feelings", title: L("Feelings", "感受"), icon: "heart.fill", tint: Theme.warn),
            Category(id: mineCategory, title: L("Mine", "我的"), icon: "person.fill", tint: Theme.teal),
        ]
    }

    static func phrases(in category: String) -> [QuickPhrase] {
        func p(_ en: String, _ zh: String, _ icon: String, _ tint: Color) -> QuickPhrase {
            QuickPhrase(text: L(en, zh), icon: icon, tint: tint)
        }
        switch category {
        case "answers":
            return [
                p("Yes", "是", "checkmark.circle.fill", Theme.live),
                p("No", "不是", "xmark.circle.fill", Theme.stop),
                p("I don't know", "我不知道", "questionmark.circle.fill", Theme.blue),
                p("Please wait", "请等一下", "hourglass", Theme.blue),
                p("Please say that again", "请再说一遍", "arrow.counterclockwise.circle.fill", Theme.blue),
                p("Thank you", "谢谢", "heart.fill", Theme.teal),
                p("Hello", "你好", "hand.wave.fill", Theme.teal),
                p("Goodbye", "再见", "figure.wave", Theme.teal),
            ]
        case "feelings":
            return [
                p("I'm okay", "我没事", "hand.thumbsup.fill", Theme.live),
                p("I'm happy to see you", "见到你很高兴", "face.smiling", Theme.warn),
                p("I'm worried", "我很担心", "exclamationmark.bubble.fill", Theme.warn),
                p("I'm frustrated", "我很烦", "cloud.rain.fill", Theme.blue),
                p("I love you", "我爱你", "heart.circle.fill", Theme.stop),
                p("I don't feel well", "我不舒服", "thermometer.medium", Theme.stop),
            ]
        default: // needs
            return [
                p("I need help", "我需要帮忙", "hand.raised.fill", Theme.stop),
                p("Water, please", "请给我水", "drop.fill", Theme.blue),
                p("I need the bathroom", "我要上厕所", "toilet.fill", Theme.teal),
                p("I'm hungry", "我饿了", "fork.knife", Theme.warn),
                p("I'm in pain", "我疼", "bandage.fill", Theme.stop),
                p("I'm cold", "我冷", "thermometer.snowflake", Theme.blue),
                p("I'm tired", "我累了", "bed.double.fill", Theme.teal),
                p("Please call my family", "请给我家人打电话", "phone.fill", Theme.live),
            ]
        }
    }
}

/// The user's own phrases, kept per language on this phone.
@MainActor
final class CustomPhrases: ObservableObject {
    @Published private(set) var items: [String] = []

    private var key: String { "quickPhrases_" + AppLanguage.current.rawValue }

    init() {
        items = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !items.contains(t) else { return }
        items.append(t)
        UserDefaults.standard.set(items, forKey: key)
    }

    func remove(_ text: String) {
        items.removeAll { $0 == text }
        UserDefaults.standard.set(items, forKey: key)
    }
}

#if DEBUG
#Preview("Phrases board") {
    QuickPhrasesView().environmentObject(SessionStore.preview())
}
#Preview("Type") {
    TypeView { _ in }.environmentObject(SessionStore.preview())
}
#endif
