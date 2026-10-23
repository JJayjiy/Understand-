import Foundation

/// A personal model is a WhisperKit (Core ML) folder built on a Mac from the
/// user's own Teach CoHear recordings (scripts/build_personal_model.sh), then
/// copied onto the phone into the app's Documents folder:
///
///   Finder → your iPhone → Files → CoHear → drag in "PersonalModel"
///
/// It never touches a server. It contains:
///   AudioEncoder.mlmodelc, TextDecoder.mlmodelc, MelSpectrogram.mlmodelc,
///   personal.json  ({"name": "...", "clips": N, "minutes": M, "built": "..."})
///
/// One slot per language (Documents/PersonalModel for English,
/// Documents/PersonalModel_zh for Chinese), so the same person can have both
/// and switching language picks the matching one. Everything below reads the
/// slot for the current language.
enum PersonalModel {
    private static let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    static func slot(for language: AppLanguage) -> URL {
        documents.appendingPathComponent(language == .zh ? "PersonalModel_zh" : "PersonalModel",
                                         isDirectory: true)
    }

    /// The slot for the current language.
    static var folder: URL { slot(for: AppLanguage.current) }

    static var isInstalled: Bool {
        ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc"].allSatisfy {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
    }

    private static var info: [String: Any]? {
        guard let d = try? Data(contentsOf: folder.appendingPathComponent("personal.json")) else { return nil }
        return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
    }

    static var name: String? {
        (info?["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Which language the model was trained on. Models built before Chinese
    /// support have no "language" key and are English.
    static var language: AppLanguage {
        AppLanguage(rawValue: info?["language"] as? String ?? "en") ?? .en
    }

    static var summary: String? {
        guard let i = info else { return nil }
        let clips = i["clips"] as? Int ?? 0
        let mins = String(format: "%.0f", i["minutes"] as? Double ?? 0)
        let lang = language.nativeName
        return L("Built from \(clips) recordings (\(mins) min, \(lang)).",
                 "由 \(clips) 段录音训练（\(mins) 分钟，\(lang)）。")
    }

    static func remove() {
        try? FileManager.default.removeItem(at: folder)
    }

    private static let parts = ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc"]

    /// Install a personal model the user picked in the Files app — for testers
    /// who can't plug their phone into the Mac that built it. Accepts either the
    /// PersonalModel folder itself or a folder that contains it (what you get
    /// when you tap a PersonalModel zip in Files to unzip it).
    static func install(from picked: URL) throws {
        let scoped = picked.startAccessingSecurityScopedResource()
        defer { if scoped { picked.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        func looksLikeModel(_ u: URL) -> Bool {
            parts.allSatisfy { fm.fileExists(atPath: u.appendingPathComponent($0).path) }
        }
        var root = picked
        if !looksLikeModel(root) {
            let nested = root.appendingPathComponent("PersonalModel", isDirectory: true)
            guard looksLikeModel(nested) else { throw InstallError.notAModel }
            root = nested
        }
        // Install into the slot for the language the model was trained on
        // (from its personal.json), whatever language the app is showing.
        var lang = AppLanguage.en
        if let d = try? Data(contentsOf: root.appendingPathComponent("personal.json")),
           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let code = j["language"] as? String, let l = AppLanguage(rawValue: code) {
            lang = l
        }
        let dest = slot(for: lang)
        // Copy to a temp name first so a failed copy never leaves a half model behind.
        let incoming = documents.appendingPathComponent("PersonalModel.incoming", isDirectory: true)
        try? fm.removeItem(at: incoming)
        try fm.copyItem(at: root, to: incoming)
        try? fm.removeItem(at: dest)
        try fm.moveItem(at: incoming, to: dest)
        installedLanguage = lang
    }

    /// Language of the most recent install, for the confirmation message.
    private(set) static var installedLanguage: AppLanguage?

    enum InstallError: LocalizedError {
        case notAModel
        var errorDescription: String? {
            L("That folder isn't a CoHear personal model. Choose the folder named PersonalModel (if you received a zip, tap it in Files first to unzip it).",
              "这个文件夹不是 CoHear 个人模型。请选择名为 PersonalModel 的文件夹（如果收到的是 zip，先在“文件”里点一下解压）。")
        }
    }
}
