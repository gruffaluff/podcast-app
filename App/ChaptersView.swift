import SwiftUI
import PodcastCore

/// The episode's chapters: tap one to jump there. "Auto-generated" chapters
/// for shows without any arrive with on-device transcripts (step 6).
struct ChaptersView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !player.showChapters.isEmpty && !player.autoChapters.isEmpty {
                    Picker("Chapters", selection: Binding(get: { player.chapterSource }, set: { player.chapterSource = $0 })) {
                        Text("From the show").tag(PlayerModel.ChapterSource.show)
                        Text("Auto-generated").tag(PlayerModel.ChapterSource.auto)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
                } else if player.showChapters.isEmpty && !player.autoChapters.isEmpty {
                    Text("Made on your iPhone from the transcript.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Theme.background)
                        .listRowSeparator(.hidden)
                }
                let current = player.currentChapterIndex
                ForEach(Array(player.chapters.enumerated()), id: \.offset) { index, chapter in
                    Button {
                        player.play(chapter: chapter)
                        dismiss()
                    } label: {
                        ChapterRow(chapter: chapter, artwork: chapter.imageURL ?? player.nowPlaying?.artworkURL, isCurrent: index == current, showTitle: player.nowPlaying?.showTitle ?? "")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.hairline)
                }
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
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ChapterRow: View {
    let chapter: Chapter
    let artwork: URL?
    let isCurrent: Bool
    let showTitle: String

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(url: artwork, title: showTitle, size: 48, radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(chapter.title)
                    .font(.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(chapter.isAd ? Theme.muted : Theme.ink)
                    .lineLimit(2)
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(isCurrent ? Theme.accentText : Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var meta: String {
        var parts = [TimeFormat.clock(chapter.start)]
        if let length = chapter.length, length > 0 { parts.append(TimeFormat.length(length)) }
        if chapter.isAd { parts.append("Skipped") }
        if isCurrent { parts.append("Playing") }
        return parts.joined(separator: " · ")
    }
}
