import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable
import PodcastCore

extension UTType {
    /// OPML show lists (declared in Config/Info.plist).
    static let opml = UTType(importedAs: "org.opml.opml", conformingTo: .xml)
}

/// The followed shows as an OPML file, for the share sheet (AirDrop, Mail,
/// Save to Files…).
struct ShowListFile: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .opml) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Podspot shows.opml")
            try Data(file.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// Shows screen section: import shows from another app, export them.
struct ImportExportSection: View {
    @Environment(LibraryStore.self) private var store
    @State private var choosingFile = false
    @State private var importing: (done: Int, total: Int)?
    @State private var message: String?

    var body: some View {
        Section {
            HStack(spacing: 10) {
                Button { choosingFile = true } label: {
                    Text(importing.map { "IMPORTING \($0.done)/\($0.total)" } ?? "↓ IMPORT")
                        .font(Theme.mono(12, .bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(KeyButtonStyle(radius: 8))
                .disabled(importing != nil)
                .accessibilityLabel("Import shows from an OPML file")

                ShareLink(item: ShowListFile(text: store.showListOPML), preview: SharePreview("Podspot shows")) {
                    Text("↑ EXPORT")
                        .font(Theme.mono(12, .bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(KeyButtonStyle(radius: 8))
                .accessibilityLabel("Export your shows as an OPML file")
            }
            .padding(.bottom, 3)
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink)
            }
        } header: {
            DeckHeader(title: "Import & export")
        } footer: {
            Text("Move your shows from or to another podcast app with an OPML file (Pocket Casts, Overcast, Castro and most others can make one; Apple Podcasts can't, so add those shows by name or link). Imported shows start on Bottom and nothing downloads until new episodes arrive.")
        }
        .listRowBackground(Theme.background)
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.opml, .xml, .data]) { result in
            guard case .success(let url) = result else { return }
            Task { await importFile(url) }
        }
    }

    private func importFile(_ url: URL) async {
        message = nil
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let shows: [OPML.Show]
        do {
            shows = try OPML.parse(try Data(contentsOf: url))
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "Couldn't read that file."
            return
        }
        importing = (0, shows.count)
        let result = await store.importShows(shows) { done in importing = (done, shows.count) }
        importing = nil

        var parts = ["Added \(result.added) show\(result.added == 1 ? "" : "s")."]
        if result.alreadyFollowed > 0 { parts.append("\(result.alreadyFollowed) you already follow.") }
        if !result.failed.isEmpty {
            parts.append("Couldn't load \(result.failed.count): \(result.failed.prefix(5).joined(separator: ", "))\(result.failed.count > 5 ? "…" : ""). Try adding those by name.")
        }
        message = parts.joined(separator: " ")
    }
}
