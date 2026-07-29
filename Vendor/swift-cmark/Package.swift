// swift-tools-version:5.3

import PackageDescription

#if os(Windows)
let cSettings: [CSetting] = [
    .define("CMARK_GFM_STATIC_DEFINE", .when(platforms: [.windows])),
]
#else
let cSettings: [CSetting] = []
#endif

// Vendored production targets from swiftlang/swift-cmark 0.8.0.
let package = Package(
    name: "cmark-gfm",
    products: [
        .library(name: "cmark-gfm", targets: ["cmark-gfm"]),
        .library(name: "cmark-gfm-extensions", targets: ["cmark-gfm-extensions"]),
    ],
    targets: [
        .target(
            name: "cmark-gfm",
            path: "src",
            exclude: [
                "scanners.re",
                "libcmark-gfm.pc.in",
                "config.h.in",
                "CMakeLists.txt",
            ],
            cSettings: cSettings
        ),
        .target(
            name: "cmark-gfm-extensions",
            dependencies: ["cmark-gfm"],
            path: "extensions",
            exclude: [
                "CMakeLists.txt",
                "ext_scanners.re",
            ],
            cSettings: cSettings
        ),
    ]
)
