// swift-tools-version: 6.3
import PackageDescription

// UI-independent learning and content model. Code here stays nonisolated by
// default so it can be verified with `swift test`, without SwiftUI or a simulator.
let package = Package(
    name: "LexcalliKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LexcalliCore", targets: ["LexcalliCore"]),
        .library(name: "LexcalliStore", targets: ["LexcalliStore"]),
        .library(name: "LexcalliImport", targets: ["LexcalliImport"]),
    ],
    dependencies: [
        // FSRS-6 is only on main; the latest tag (5.0.0) is FSRS-5. Pin the commit until a tag ships.
        .package(
            url: "https://github.com/open-spaced-repetition/swift-fsrs.git",
            revision: "4fbaf20184d62f82a9f44f343337c61a2c5483e9"
        ),
        // LexcalliStore only; LexcalliCore never imports it.
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"),
        // LexcalliImport only. ZIPFoundation: MIT; zstd: BSD-3-Clause, of its dual license.
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20"),
        .package(url: "https://github.com/facebook/zstd.git", exact: "1.5.7"),
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
        .target(
            name: "LexcalliStore",
            dependencies: ["LexcalliCore", .product(name: "GRDB", package: "GRDB.swift")],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .target(
            name: "LexcalliImport",
            dependencies: [
                "LexcalliCore",
                "LexcalliStore",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "libzstd", package: "zstd"),
            ],
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
        .testTarget(
            name: "LexcalliStoreTests",
            dependencies: ["LexcalliCore", "LexcalliStore", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(
            name: "LexcalliImportTests",
            dependencies: [
                "LexcalliImport", "LexcalliCore", "LexcalliStore", .product(name: "GRDB", package: "GRDB.swift"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
