// swift-tools-version: 6.2

import PackageDescription

// Vendored from swiftlang/swift-markdown 0.8.0 so Xcode can build the app
// without reaching GitHub during package resolution.
let package = Package(
    name: "swift-markdown",
    products: [
        .library(name: "Markdown", targets: ["Markdown"]),
    ],
    dependencies: [
        .package(path: "../swift-cmark"),
    ],
    targets: [
        .target(
            name: "Markdown",
            dependencies: [
                "CAtomic",
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ],
            exclude: ["CMakeLists.txt"],
            swiftSettings: [
                .unsafeFlags(
                    ["-Xcc", "-DCMARK_GFM_STATIC_DEFINE"],
                    .when(platforms: [.windows])
                ),
            ]
        ),
        .target(name: "CAtomic"),
    ],
    swiftLanguageModes: [.v5]
)
