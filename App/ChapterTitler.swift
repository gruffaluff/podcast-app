import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
import PodcastCore

/// Gives auto-generated chapters proper titles using Apple's on-device
/// language model (Apple Intelligence), when the iPhone has it. Runs on the
/// phone, costs nothing; otherwise the word-based titles stay.
enum ChapterTitler {
    static func retitle(_ chapters: [Chapter], lines: [TranscriptLayout.Line]) async -> [Chapter] {
        #if canImport(FoundationModels)
        guard SystemLanguageModel.default.availability == .available else { return chapters }
        var result = chapters
        for index in result.indices where !result[index].isAd {
            let chapter = result[index]
            let end = chapter.end ?? .greatestFiniteMagnitude
            let text = lines.filter { $0.start >= chapter.start && $0.start < end }.map(\.text).joined(separator: " ")
            let excerpt = text.split(separator: " ").prefix(450).joined(separator: " ")
            guard excerpt.count > 200 else { continue }
            let session = LanguageModelSession(instructions: """
                You write short, specific chapter titles for podcast episodes. \
                Reply with the title only: 2 to 6 words, no quotation marks, no full stop.
                """)
            guard let response = try? await session.respond(to: "Title this part of the episode:\n\n\(excerpt)") else { continue }
            let title = response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'.*#"))
            if !title.isEmpty, title.count <= 60, !title.contains("\n") {
                result[index].title = title
            }
        }
        return result
        #else
        return chapters
        #endif
    }
}
