// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoleWidget",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MoleWidgetCore", targets: ["MoleWidgetCore"]),
        .executable(name: "MoleWidget", targets: ["MoleWidget"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "MoleWidgetCore",
            path: "Sources/MoleWidgetCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "MoleWidget",
            dependencies: [
                "MoleWidgetCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/MoleWidget",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MoleWidgetCoreTests",
            dependencies: ["MoleWidgetCore"],
            path: "Tests/MoleWidgetCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                // Swift Testing in Command Line Tools ships as a separate framework
                // (these flags are harmless with a full Xcode install)
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib",
                ])
            ]
        ),
    ]
)
