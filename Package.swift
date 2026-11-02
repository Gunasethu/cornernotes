// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CornerNotes",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CornerNotes", targets: ["CornerNotes"])
    ],
    targets: [
        .executableTarget(
            name: "CornerNotes",
            path: "Sources/CornerNotes"
        )
    ]
)