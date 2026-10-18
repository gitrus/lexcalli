// swift-tools-version: 6.3
import PackageDescription

// UI-independent learning and content model. Code here stays nonisolated by
// default so it can be verified with `swift test`, without SwiftUI or a simulator.
let package = Package(
    name: "LexcalliCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LexcalliCore", targets: ["LexcalliCore"])
    ],
    dependencies: [
        // FSRS-6 is only on main; the latest tag (5.0.0) is FSRS-5. Pin the commit until a tag ships.
        .package(
            url: "https://github.com/open-spaced-repetition/swift-fsrs.git",
            revision: "4fbaf20184d62f82a9f44f343337c61a2c5483e9"
        )
    ],
    targets: [
        .target(
            name: "LexcalliCore",
            dependencies: [.product(name: "FSRS", package: "swift-fsrs")],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "LexcalliCoreTests",
            dependencies: [
                "LexcalliCore",
                .product(name: "FSRS", package: "swift-fsrs"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
