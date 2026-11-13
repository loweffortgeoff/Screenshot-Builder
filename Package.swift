// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenshotBuilder",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ScreenshotBuilder", targets: ["ScreenshotBuilder"])],
    targets: [
        .executableTarget(name: "ScreenshotBuilder"),
        .testTarget(name: "ScreenshotBuilderTests", dependencies: ["ScreenshotBuilder"])
    ]
)
