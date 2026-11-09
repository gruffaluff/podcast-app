import SwiftUI
import PodcastCore

/// A slim progress line (how far through an episode).
struct ProgressLine: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.hairline)
                Capsule().fill(Theme.accentFill)
                    .frame(width: max(4, geometry.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// One episode in Continue listening / History.
struct HistoryRow: View {
    let episode: PodcastEpisode
    var showsProgress = true

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: episode.artwork, title: episode.podcast?.title ?? episode.title, size: 48, radius: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(Theme.text(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                // The show on its own line, then played / time left and
                // when on a line of their own (Paul, 9 Nov 2026: behind a
                // long show name they were cut off).
                if let show = episode.podcast?.title, !show.isEmpty {
                    Text(show.uppercased())
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                if !status.isEmpty {
                    Text(status.uppercased())
                        .font(Theme.mono(10, .medium))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .lineLimit(1)
                }
                if showsProgress, !episode.played, let duration = episode.duration, duration > 0 {
                    ProgressLine(fraction: episode.position / duration)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var status: String {
        var parts: [String] = []
        if episode.played {
            parts.append("Played")
        } else if let left = episode.timeLeft, left > 0 {
            parts.append("\(TimeFormat.length(left)) left")
        }
        if let when = episode.lastPlayedAt { parts.append(TimeFormat.ago(when)) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Everything Paul has listened to, most recent first.
struct HistoryView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @State private var episodes: [PodcastEpisode] = []

    var body: some View {
        List {
            if episodes.isEmpty {
                Text("Episodes you play will appear here.")
                    .foregroundStyle(Theme.muted)
                    .listRowBackground(Theme.background)
            }
            ForEach(episodes) { episode in
                Button { player.play(episode) } label: { HistoryRow(episode: episode) }
                    .buttonStyle(.plain)
                    .contextMenu { EpisodeMenuItems(episode: episode) }
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.hairline)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("HISTORY")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { episodes = store.listeningHistory() }
    }
}

/// How much Paul listens: this week, this month, all time, top shows.
struct StatsView: View {
    @Environment(LibraryStore.self) private var store
    @State private var stats = LibraryStore.ListeningStats()
    @State private var runs: [TranscriptionLog.Run] = TranscriptionLog.all
    @State private var week = WeekStats.current

    /// This week at a glance: listened, saved by speed and trims, ads skipped.
    private var weekSummary: some View {
        HStack(alignment: .top, spacing: 10) {
            weekFigure(Self.hours(week.listened), "LISTENED")
            weekFigure(Self.hours(week.saved), "SAVED BY SPEED & TRIMS")
            weekFigure(week.adsSkipped == 0 ? "0" : "\(week.adsSkipped) · \(Self.hours(week.adSeconds))", "ADS SKIPPED")
        }
    }

    private func weekFigure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.big(24))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(Theme.mono(9, .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    /// How long transcripts take on this iPhone.
    @ViewBuilder private var transcriptStats: some View {
        let finished = runs.filter(\.finished)
        DeckHeader(title: "Transcripts", detail: finished.isEmpty ? nil : "\(finished.count) made on this iPhone")
        if finished.isEmpty {
            Text("Transcripts made on this iPhone will show how long they took here.")
                .foregroundStyle(Theme.muted)
        } else {
            let total = finished.map(\.seconds).reduce(0, +)
            let audio = finished.map(\.audioSeconds).reduce(0, +)
            let perHour = audio > 0 ? total / audio * 60 : 0
            let longest = finished.max { $0.seconds < $1.seconds }
            let shortest = finished.min { $0.seconds < $1.seconds }
            let stopped = runs.count - finished.count
            VStack(spacing: 8) {
                statRow("Time spent transcribing", Self.duration(total))
                statRow("Average per hour of audio", "\(String(format: "%.1f", perHour)) min")
                if let longest { statRow("Longest", Self.duration(longest.seconds)) }
                if let shortest { statRow("Shortest", Self.duration(shortest.seconds)) }
                if let latest = finished.last { statRow("Latest", Self.duration(latest.seconds)) }
                if stopped > 0 { statRow("Stopped", "\(stopped)") }
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Theme.muted)
            Spacer(minLength: 12)
            Text(value).foregroundStyle(Theme.ink).fontWeight(.semibold).lineLimit(1).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total >= 3600 { return "\(total / 3600) h \(total % 3600 / 60) min" }
        if total >= 60 { return "\(total / 60) min \(total % 60) s" }
        return "\(total) s"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DeckHeader(title: "This week", detail: nil)
                weekSummary
                DeckDisplay {
                    Text("LISTENED").font(Theme.mono(11)).foregroundStyle(Theme.displayDim)
                    HStack(alignment: .firstTextBaseline, spacing: 18) {
                        figure(stats.week, "THIS WEEK")
                        figure(stats.month, "30 DAYS")
                        figure(stats.allTime, "ALL TIME")
                    }
                    weekBars
                }
                DeckHeader(title: "Top shows", detail: "\(stats.finishedThisMonth) finished in 30 days")
                if stats.topShows.isEmpty {
                    Text("Listen to something and your top shows will show up here.")
                        .foregroundStyle(Theme.muted)
                }
                ForEach(Array(stats.topShows.enumerated()), id: \.offset) { index, show in
                    HStack {
                        Text(String(format: "%02d", index + 1))
                            .font(Theme.mono(14, .bold))
                            .foregroundStyle(index == 0 ? Theme.accentText : Theme.muted)
                            .frame(width: 28, alignment: .leading)
                        Text(show.title).foregroundStyle(Theme.ink).lineLimit(1)
                        Spacer()
                        Text(Self.hours(show.seconds))
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 2)
                }
                Text("Counts time actually playing, at whatever speed you listen.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                transcriptStats
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("STATS")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { stats = store.listeningStats() }
    }

    private func figure(_ seconds: TimeInterval, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.hours(seconds)).font(Theme.mono(22, .bold))
            Text(label).font(Theme.mono(9)).foregroundStyle(Theme.displayDim)
        }
    }

    /// The last 7 days as a row of bars.
    private var weekBars: some View {
        let peak = max(stats.lastSevenDays.map(\.seconds).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(stats.lastSevenDays.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(day.seconds > 0 ? Theme.displayText : Theme.displayTrack)
                        .frame(height: max(3, 50 * day.seconds / peak))
                    Text(day.day.formatted(.dateTime.weekday(.narrow)))
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.displayDim)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 70, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel("Listening each day this week")
    }

    static func hours(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes)M" : "\(minutes / 60)H \(minutes % 60)M"
    }
}

/// Space used by downloads, per show, with delete and per-show limits.
struct StorageView: View {
    @Environment(LibraryStore.self) private var store
    @State private var rows: [LibraryStore.ShowStorage] = []
    @State private var transcriptBytes: Int64 = 0
    @State private var confirmingDeleteAll = false
    /// A show whose downloads are about to be deleted (asks first, like
    /// every action that can't be undone).
    @State private var deletingShow: LibraryStore.ShowStorage?

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Downloads").foregroundStyle(Theme.ink)
                    Spacer()
                    Text(Self.size(rows.reduce(0) { $0 + $1.bytes })).font(Theme.mono(13)).foregroundStyle(Theme.ink)
                }
                HStack {
                    Text("Transcripts").foregroundStyle(Theme.ink)
                    Spacer()
                    Text(Self.size(transcriptBytes)).font(Theme.mono(13)).foregroundStyle(Theme.muted)
                }
                Button("Delete all downloads", role: .destructive) { confirmingDeleteAll = true }
                    .disabled(rows.isEmpty)
            } header: {
                DeckHeader(title: "On this iPhone")
            }
            .listRowBackground(Theme.background)

            Section {
                if rows.isEmpty {
                    Text("Nothing downloaded.").foregroundStyle(Theme.muted)
                        .listRowBackground(Theme.background)
                }
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            ArtworkView(url: row.show.artworkURL, title: row.show.title, size: 40, radius: 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.show.title).foregroundStyle(Theme.ink).lineLimit(1)
                                Text("\(row.count) EPISODE\(row.count == 1 ? "" : "S") · \(Self.size(row.bytes))")
                                    .font(Theme.mono(10))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Menu {
                                Picker("Keep downloads", selection: Binding(get: { row.show.downloadLimit }, set: { store.setDownloadLimit($0, for: row.show); reload() })) {
                                    Text("Keep all").tag(0)
                                    ForEach([1, 2, 3, 5, 10], id: \.self) { Text("Keep latest \($0)").tag($0) }
                                }
                                Button("Delete these downloads", systemImage: "trash", role: .destructive) {
                                    deletingShow = row
                                }
                            } label: {
                                Text(row.show.downloadLimit == 0 ? "ALL ▾" : "LATEST \(row.show.downloadLimit) ▾")
                                    .font(Theme.mono(10, .bold))
                                    .foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 8)
                                    .frame(minHeight: 32)
                                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.hairline)
                }
                // A plain row, not a section footer: in this plain list iOS
                // put the footer on a white block.
                Text("Played episodes' downloads are deleted automatically (straight away, or after 24 hours if you chose that). \"Latest 3\" keeps only a show's three newest downloads.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
            } header: {
                DeckHeader(title: "By show")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("STORAGE")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .alert("Delete all downloads?", isPresented: $confirmingDeleteAll) {
            Button("Cancel", role: .cancel) {}
            Button("Delete all", role: .destructive) {
                store.removeAllDownloads()
                reload()
            }
        } message: {
            Text("Episodes stay in your library and Up Next; you can download them again.")
        }
        .alert("Delete \(deletingShow?.show.title ?? "these") downloads?", isPresented: Binding(get: { deletingShow != nil }, set: { if !$0 { deletingShow = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let row = deletingShow { store.removeDownloads(of: row.show) }
                deletingShow = nil
                reload()
            }
        } message: {
            Text("Episodes stay in your library and Up Next; you can download them again.")
        }
    }

    private func reload() {
        rows = store.storageByShow()
        transcriptBytes = store.transcriptBytes()
    }

    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file).uppercased()
    }
}
