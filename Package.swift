// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Whisp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Whisp", targets: ["Whisp"])
    ],
    targets: [
        .executableTarget(
            name: "Whisp",
            path: "Sources/Whisp"
        )
    ]
)
