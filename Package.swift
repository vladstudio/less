// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Menuless",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Menuless",
            path: "Menuless",
            exclude: ["Info.plist"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
