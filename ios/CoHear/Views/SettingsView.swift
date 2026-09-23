import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false
    @State private var modelName = "Loading…"

    private var modelNote: String {
        modelName.hasPrefix("CoHear")
            ? "Adapted on speech from adults with cerebral palsy and ALS. Word error on the most severely affected test speaker: 34.6%, down from 84.4%."
            : "The general-purpose model. The CoHear model couldn't be loaded — check your connection and reopen the app."
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Text size") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("The quick brown fox")
                            .font(Theme.body(session.textScale))
                        Slider(value: $session.textScale, in: 0.8...2.2, step: 0.1)
                            .accessibilityLabel("Text size")
                            .accessibilityValue("\(Int(session.textScale * 100)) percent")
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Toggle(isOn: $session.clarifyEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Clarify").font(Theme.label())
                            Text("Clean up what was heard and add a one-line summary. Runs on this phone.")
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
                    Text("Clarify")
                }

                Section {
                    Toggle(isOn: $session.filterOtherVoices) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Only my voice").font(Theme.label())
                            Text("Dims lines that sound like someone else, and leaves them out of Show and Speak. Nothing is ever deleted — tap any line to correct it.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: Theme.minTarget)

                    Text("This is a guess based on pitch and voice quality. It works best when the other person's voice is clearly different from yours, and it will sometimes be wrong.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Other voices")
                }

                Section("This session") {
                    Button(role: .destructive) { confirmingClear = true } label: {
                        Label("Clear everything said", systemImage: "trash")
                            .font(Theme.label())
                            .frame(minHeight: Theme.minTarget)
                    }
                    .disabled(session.utterances.isEmpty)
                }

                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Your voice never leaves this phone.", systemImage: "lock.fill")
                            .font(Theme.label())
                        Text("Speech recognition and Clarify both run on the device. CoHear has no server, no account, and no analytics. Nothing you say is stored after you close the app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("The speech model is downloaded once from Hugging Face on first launch. That download is the only network request the app makes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("Speech model") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(modelName).font(Theme.label())
                        Text(modelNote)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .task { modelName = await session.transcriber.loadedName }
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CoHear helps a listener understand you. It never speaks for you. What it hears is shown only to you until you choose to show it to someone else.")
                            .font(.subheadline)
                        Text("This is a research tool, not a medical device. It has not been clinically validated and should not be relied on where a mistake would matter — medical, legal, or financial decisions. It is wrong sometimes. Read what it wrote before you show it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Link("Research and source code", destination: URL(string: "https://github.com/JJayjiy/Understand-")!)
                            .font(Theme.label())
                            .frame(minHeight: Theme.minTarget)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.label())
                        .frame(minHeight: Theme.minTarget)
                }
            }
            .confirmationDialog("Clear everything from this session?", isPresented: $confirmingClear,
                                titleVisibility: .visible) {
                Button("Clear", role: .destructive) { session.clearAll() }
                Button("Keep it", role: .cancel) {}
            }
        }
    }
}

#if DEBUG
#Preview {
    SettingsView().environmentObject(SessionStore.preview())
}
#endif
