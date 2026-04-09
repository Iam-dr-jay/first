// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NeuralFeel",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "NeuralFeel", targets: ["NeuralFeel"])
    ],
    targets: [
        .target(
            name: "NeuralFeel",
            path: "Sources/NeuralFeel",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
