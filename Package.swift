// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Speak11",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Speak11", targets: ["Speak11"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            exact: "0.15.5"
        ),
    ],
    targets: [
        .executableTarget(
            name: "Speak11",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .testTarget(
            name: "Speak11Tests",
            dependencies: ["Speak11"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
