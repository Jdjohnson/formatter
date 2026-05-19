// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Formatter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Formatter", targets: ["Formatter"])
    ],
    targets: [
        .executableTarget(
            name: "Formatter",
            path: "Sources/Formatter"
        ),
        .testTarget(
            name: "FormatterTests",
            dependencies: ["Formatter"],
            path: "Tests/FormatterTests"
        )
    ]
)
