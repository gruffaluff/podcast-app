// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PodcastCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PodcastCore", targets: ["PodcastCore"])
    ],
    targets: [
        .target(name: "PodcastCore"),
        .testTarget(name: "PodcastCoreTests", dependencies: ["PodcastCore"])
    ]
)
