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
                    .accessibilityLabel("Edit what you said")

                if utterance.isClarified, utterance.edited == nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Originally heard as")
                            .font(Theme.label()).foregroundStyle(.secondary)
                        Text(utterance.raw)
                            .font(Theme.label())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Use the original instead") { text = utterance.raw }
                            .font(Theme.label())
                            .frame(minHeight: Theme.minTarget)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                PillButton(title: "Save", systemImage: "checkmark", tint: Theme.blue, filled: true) {
                    session.update(utterance.id, text: text)
                    dismiss()
                }

                HStack(spacing: 12) {
                    if session.filterOtherVoices, utterance.voice != .other {
                        PillButton(title: "Not me", systemImage: "person.2", tint: Theme.teal, filled: false) {
                            session.setOwnVoice(utterance.id, isOwn: false)
                            dismiss()
                        }
                    }
                    PillButton(title: "Delete", systemImage: "trash", tint: Theme.stop, filled: false) {
                        confirmingDelete = true
                    }
                }
            }
            .padding(Theme.spacing)
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Edit this line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.label())
                        .frame(minHeight: Theme.minTarget)
                }
            }
            .confirmationDialog("Delete this?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    session.delete(utterance.id)
                    dismiss()
                }
                Button("Keep it", role: .cancel) {}
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
