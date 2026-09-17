// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StopMeow",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StopMeow",
            path: "Sources/StopMeow",
            exclude: ["Detection/README.md", "Customize/README.md", "Gallery/README.md"]
        )
    ]
)
