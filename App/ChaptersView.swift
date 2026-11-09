import SwiftUI
import PodcastCore

/// The episode's chapters: tap one to jump there. "Auto-generated" chapters
/// for shows without any arrive with on-device transcripts (step 6).
struct ChaptersView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let current = player.currentChapterIndex
        NavigationStack {
            // Looks like the pulled-up Up Next list: inset paper rows,
            // small artwork, one-line titles, a summary line at the top.
            List {
                Section {
                    // A plain row, not a section header (plain lists pin headers).
                    header
                        .listRowBackground(Theme.background)
                        .listRowSeparator(.hidden)
                    ForEach(Array(player.chapters.enumerated()), id: \.offset) { index, chapter in
                        Button {
                            player.play(chapter: chapter)
                            dismiss()
                        } label: {
                            ChapterRow(chapter: chapter, artwork: chapter.imageURL ?? player.nowPlaying?.artworkURL,
                                       isCurrent: index == current, isNext: index == (current ?? -1) + 1,
                                       showTitle: player.nowPlaying?.showTitle ?? "")
                        }
                        .buttonStyle(.plain)
                        // Flat banded rows like every other list.
                        .listRowBackground(index == current ? Theme.highlight : Theme.band(index))
                        .listRowSeparator(.hidden)
                    }
                }
                .listSectionSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .overlay {
                if player.chapters.isEmpty {
                    ContentUnavailableView("No chapters", systemImage: "list.bullet.rectangle", description: Text("This episode doesn't come with chapters. They're made automatically once it has a transcript."))
                        .foregroundStyle(Theme.muted)
                }
            }
            .navigationTitle("CHAPTERS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// "8 chapters · From the show", with the From the show / Auto switch
    /// when both kinds exist.
    @ViewBuilder private var header: some View {
        let count = "\(player.chapters.count) chapter\(player.chapters.count == 1 ? "" : "s")"
        VStack(alignment: .leading, spacing: 8) {
            if !player.showChapters.isEmpty && !player.autoChapters.isEmpty {
                DeckSwitch(options: [(label: "From the show", value: PlayerModel.ChapterSource.show), (label: "Auto", value: .auto)],
                           selection: Binding(get: { player.chapterSource }, set: { player.chapterSource = $0 }))
            }
            Text(player.showChapters.isEmpty && !player.autoChapters.isEmpty ? "\(count) · made on your iPhone from the transcript" : count)
                .font(Theme.mono(12))
                .foregroundStyle(Theme.muted)
        }
        .textCase(nil)
    }
}

private struct ChapterRow: View {
    let chapter: Chapter
    let artwork: URL?
    let isCurrent: Bool
    let isNext: Bool
    let showTitle: String

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: artwork, title: showTitle, size: 42, radius: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
                    .font(Theme.text(15, .bold))
                    .foregroundStyle(chapter.isAd ? Theme.muted : Theme.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if isCurrent {
                        DeckTag(text: "NOW")
                    } else if isNext {
                        DeckTag(text: "NEXT")
                    }
                    Text(meta)
                        .font(Theme.text(12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var meta: String {
        var parts = [TimeFormat.clock(chapter.start)]
        if let length = chapter.length, length > 0 { parts.append(TimeFormat.length(length)) }
        if chapter.isAd { parts.append("Skipped") }
        return parts.joined(separator: " · ")
    }
}
