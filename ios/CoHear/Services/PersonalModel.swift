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
enum PersonalModel {
    static let folder: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PersonalModel", isDirectory: true)

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

    static var summary: String? {
        guard let i = info else { return nil }
        let clips = i["clips"] as? Int ?? 0
        let mins = i["minutes"] as? Double ?? 0
        return "Built from \(clips) recordings (\(String(format: "%.0f", mins)) min)."
    }

    static func remove() {
        try? FileManager.default.removeItem(at: folder)
    }
}
