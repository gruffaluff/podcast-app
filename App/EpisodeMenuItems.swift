import SwiftUI

/// Play next / Play last / played actions, shared by cards and lists.
struct EpisodeMenuItems: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DownloadManager.self) private var downloads
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode

    var body: some View {
        Button("Play", systemImage: "play") { player.play(episode) }
        Button("Episode notes", systemImage: "doc.text") { store.notesEpisode = episode }
        Button("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") { store.playNext(episode) }
        Button("Play last", systemImage: "text.line.last.and.arrowtriangle.forward") { store.playLast(episode) }
        if downloads.progress[episode.episodeID] != nil {
            Button("Stop download", systemImage: "xmark.circle") { store.removeDownload(episode) }
        } else if episode.downloadFile != nil {
            Button("Remove download", systemImage: "trash", role: .destructive) { store.removeDownload(episode) }
        } else {
            Button("Download", systemImage: "arrow.down.circle") { downloads.download(episode) }
        }
        if transcripts.isQueued(episode) {
            Button("Stop transcribing", systemImage: "stop.circle") { transcripts.stop(episode) }
        } else if transcripts.canTranscribeNow(episode) {
            Button("Transcribe now", systemImage: "text.quote") { transcripts.transcribeNow(episode) }
        }
        if episode.played {
            Button("Mark as unplayed", systemImage: "circle") { store.markUnplayed(episode) }
        } else {
            Button("Mark as played", systemImage: "checkmark.circle") {
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            }
        }
    }
}
