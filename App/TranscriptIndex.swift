import Foundation
import PodcastCore

/// Searches transcript files off the main thread, keeping their lines in
/// memory after the first search.
actor TranscriptIndex {
    static let shared = TranscriptIndex()

    struct File: Sendable {
        let episodeID: String
        let fileName: String
    }

    struct Result: Sendable {
        let episodeID: String
        let matches: [TranscriptSearch.Match]
    }

    private var cache: [String: [TranscriptLayout.Line]] = [:]

    func search(_ query: String, in files: [File]) -> [Result] {
        var results: [Result] = []
        for file in files {
            if Task.isCancelled { break }
            let lines: [TranscriptLayout.Line]
            if let cached = cache[file.fileName] {
                lines = cached
            } else {
                lines = TranscriptFiles.load(file.fileName).map { TranscriptLayout.lines(from: $0.segments) } ?? []
                cache[file.fileName] = lines
            }
            let matches = TranscriptSearch.matches(of: query, in: lines)
            if !matches.isEmpty { results.append(Result(episodeID: file.episodeID, matches: matches)) }
        }
        return results
    }
}
