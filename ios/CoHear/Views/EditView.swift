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
                    .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
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

                BigButton(title: "Save", systemImage: "checkmark", tint: .accentColor) {
                    session.update(utterance.id, text: text)
                    dismiss()
                }

                BigButton(title: "Delete", systemImage: "trash", tint: .red.opacity(0.85)) {
                    confirmingDelete = true
                }
            }
            .padding(Theme.spacing)
            .navigationTitle("Edit")
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
