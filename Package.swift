// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Less",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../app-kit"),
    ],
    targets: [
        .executableTarget(
            name: "Less",
            dependencies: [.product(name: "MacAppKit", package: "app-kit")],
            path: "Less",
            exclude: ["Info.plist"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
