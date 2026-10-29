import Foundation

/// File names for downloaded episodes: short, stable and safe, whatever
/// characters the episode's ID or audio link contains.
public enum DownloadNaming {
    static let audioExtensions: Set<String> = ["mp3", "m4a", "m4b", "aac", "mp4", "ogg", "oga", "opus", "wav", "flac"]

    /// The same episode always gets the same name, e.g. "a3f09c1d2e4b5a67.mp3".
    public static func fileName(episodeID: String, audioURL: URL) -> String {
        let ext = audioURL.pathExtension.lowercased()
        return "\(stableHash(episodeID)).\(audioExtensions.contains(ext) ? ext : "mp3")"
    }

    /// 64-bit FNV-1a as 16 hex digits. Stable across launches, unlike `hashValue`.
    static func stableHash(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex
    }
}
