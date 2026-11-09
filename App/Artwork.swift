import SwiftUI
import UIKit
import CryptoKit

/// Show or episode artwork, with a calm coloured tile and initials while it
/// loads or if there is none. Images come from `ArtworkImageCache`, so each
/// picture is downloaded once and then shows instantly (also offline).
struct ArtworkView: View {
    let url: URL?
    let title: String
    var size: CGFloat = 52
    var radius: CGFloat = 10

    var body: some View {
        CachedImage(url: url) { placeholder }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Theme.placeholderColor(for: title)
            .overlay(
                Text(Theme.initials(for: title))
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(Theme.background)
            )
    }
}

/// An image from the artwork cache, filling its frame.
struct CachedImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: Placeholder
    @State private var image: UIImage?

    init(url: URL?, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
        _image = State(initialValue: url.flatMap { ArtworkImageCache.shared.cached($0) })
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            if let cached = ArtworkImageCache.shared.cached(url) { image = cached; return }
            image = await ArtworkImageCache.shared.image(for: url)
        }
    }
}

/// Artwork kept in memory and in the app's Caches folder (iOS may clear that
/// when space is short; it's re-downloaded then). Large pictures are saved
/// at most 600 points across, which is plenty for every screen.
@MainActor
final class ArtworkImageCache {
    static let shared = ArtworkImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let directory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    init() {
        memory.countLimit = 300
        // About 80 MB of decoded pictures at most (review, 9 Nov 2026: a
        // count alone allowed ~400 MB of 600-point images).
        memory.totalCostLimit = 80 * 1024 * 1024
    }

    /// "Refresh artwork": forget every saved picture; each is fetched again
    /// the next time it's shown (shows that changed their artwork update).
    func clear() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func cached(_ url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let image = cached(url) { return image }
        if let task = inFlight[url] { return await task.value }
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent(digest + ".jpg")
        let task = Task.detached(priority: .utility) { () -> UIImage? in
            if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
                return image.preparingForDisplay() ?? image
            }
            guard let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) else { return nil }
            let longest = max(image.size.width, image.size.height)
            var result = image
            if longest > 600 {
                let scale = 600 / longest
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                result = image.preparingThumbnail(of: size) ?? image
            }
            if let jpeg = result.jpegData(compressionQuality: 0.85) {
                try? jpeg.write(to: file, options: .atomic)
            }
            return result.preparingForDisplay() ?? result
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image { memory.setObject(image, forKey: url as NSURL, cost: Self.cost(of: image)) }
        return image
    }

    /// Bytes the decoded picture takes in memory.
    private static func cost(of image: UIImage) -> Int {
        Int(image.size.width * image.scale * image.size.height * image.scale * 4)
    }
}
