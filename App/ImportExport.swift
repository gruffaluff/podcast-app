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
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Poddeck shows.opml")
            try Data(file.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
