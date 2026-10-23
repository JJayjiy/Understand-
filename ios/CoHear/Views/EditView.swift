import SwiftUI

/// Edit one utterance. The model is wrong a third of the time; the speaker is
/// the only person who knows what they meant, so editing has to be easy and
/// deleting has to be safe.
///
/// No swipe-to-delete anywhere in the app. Delete is a big button that asks.
struct EditView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let utterance: Utterance
    @State private var text: String = ""
    @State private var confirmingDelete = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing) {
                TextEditor(text: $text)
                    .font(Theme.body(session.textScale))
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .focused($focused)
                    .accessibilityLabel(L("Edit what you said", "修改你说的话"))

                if utterance.isClarified, utterance.edited == nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Originally heard as", "原本听到的是"))
                            .font(Theme.label()).foregroundStyle(.secondary)
                        Text(utterance.raw)
                            .font(Theme.label())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(L("Use the original instead", "改用原文")) { text = utterance.raw }
                            .font(Theme.label())
                            .frame(minHeight: Theme.minTarget)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                PillButton(title: L("Save", "保存"), systemImage: "checkmark", tint: Theme.blue, filled: true) {
                    session.update(utterance.id, text: text)
                    dismiss()
                }

                HStack(spacing: 12) {
                    if session.filterOtherVoices, utterance.voice != .other {
                        PillButton(title: L("Not me", "不是我"), systemImage: "person.2", tint: Theme.teal, filled: false) {
                            session.setOwnVoice(utterance.id, isOwn: false)
                            dismiss()
                        }
                    }
                    PillButton(title: L("Delete", "删除"), systemImage: "trash", tint: Theme.stop, filled: false) {
                        confirmingDelete = true
                    }
                }
            }
            .padding(Theme.spacing)
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(L("Edit this line", "修改这一句"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel", "取消")) { dismiss() }
                        .font(Theme.label())
                        .frame(minHeight: Theme.minTarget)
                }
            }
            .confirmationDialog(L("Delete this?", "删除这一句？"), isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button(L("Delete", "删除"), role: .destructive) {
                    session.delete(utterance.id)
                    dismiss()
                }
                Button(L("Keep it", "保留"), role: .cancel) {}
            }
            .onAppear {
                text = utterance.text
                focused = true
            }
        }
    }
}

#if DEBUG
#Preview {
    EditView(utterance: Utterance(raw: "Can we go to the park after lunch"))
        .environmentObject(SessionStore.preview())
}
#endif
