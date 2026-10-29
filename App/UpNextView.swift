import SwiftUI
import PodcastCore

struct UpNextView: View {
    @State private var queue: [QueueItem] = SampleData.initialQueue()
    @State private var checkedLabel = "Checked 2 hours ago · pull to check now"
    private let settings = SampleData.settings

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(queue, id: \.episode.id) { item in
                        QueueRow(item: item, settings: settings)
                            .swipeActions(edge: .trailing) {
                                Button("Played") {
                                    queue = QueueEngine.complete(item.episode.id, in: queue)
                                }
                                .tint(Theme.accentFill)
                            }
                    }
                    .onMove { from, to in queue.move(fromOffsets: from, toOffset: to) }
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.hairline)
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(checkedLabel)
                        Text("\(queue.count) episodes")
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .refreshable { checkForNewEpisodes() }
            .navigationTitle("Up Next")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }

    /// Stand-in for the real feed check: adds sample arrivals using the queue rules.
    private func checkForNewEpisodes() {
        queue = QueueEngine.addNewEpisodes(SampleData.arrivals, to: queue, settings: settings)
        checkedLabel = "Up to date · checked just now"
    }
}

private struct QueueRow: View {
    let item: QueueItem
    let settings: QueueSettings

    var body: some View {
        let show = SampleData.shows[item.episode.showID]
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(show?.color ?? Theme.muted)
                .frame(width: 52, height: 52)
                .overlay(
                    Text(show?.initials ?? "")
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(Theme.background)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(show?.name ?? "")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Text(item.episode.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(sourceLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 6)
    }

    private var sourceLabel: String {
        switch item.source {
        case .manual:
            return "Added by you"
        case .auto:
            switch settings.mode(for: item.episode.showID) {
            case .top: return "Auto · Top"
            case .bottom: return "Auto · Bottom"
            case .off: return "Auto"
            }
        }
    }
}
