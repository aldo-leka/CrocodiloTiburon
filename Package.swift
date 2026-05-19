// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CrocodiloTiburon",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CrocodiloTiburon",
            targets: ["CrocodiloTiburonApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.3")
    ],
    targets: [
        .executableTarget(
            name: "CrocodiloTiburonApp",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/CrocodiloTiburonApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
