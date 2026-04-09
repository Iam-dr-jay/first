// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NeuralFeel",
    platforms: [
        .watchOS(.v10),
        .iOS(.v17)
    ],
    products: [
        .library(name: "NeuralFeelWatch", targets: ["NeuralFeelWatch"]),
        .library(name: "NeuralFeelPhone", targets: ["NeuralFeelPhone"])
    ],
    targets: [
        // Apple Watch target
        .target(
            name: "NeuralFeelWatch",
            path: "Sources/NeuralFeelWatch",
            resources: [
                .process("Resources")
            ]
        ),
        // iPhone 13 Pro Max companion console target
        .target(
            name: "NeuralFeelPhone",
            dependencies: ["NeuralFeelWatch"],   // shares FeelProgram model
            path: "Sources/NeuralFeelPhone"
        )
    ]
)
