// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "AgenticExecution",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "AgenticExecution",
            targets: [
                "AgenticExecution",
            ]
        ),
        .executable(
            name: "aetest",
            targets: [
                "AgenticExecutionTestFlows",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Agentic.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/AgenticWorkspace.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Schema.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Difference.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "AgenticExecution",
            dependencies: [
                .product(
                    name: "Agentic",
                    package: "Agentic"
                ),
                .product(
                    name: "AgenticWorkspace",
                    package: "AgenticWorkspace"
                ),
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
                .product(
                    name: "Schema",
                    package: "Schema"
                ),
                .product(
                    name: "Difference",
                    package: "Difference"
                ),
            ]
        ),
        .executableTarget(
            name: "AgenticExecutionTestFlows",
            dependencies: [
                "AgenticExecution",
                .product(
                    name: "Agentic",
                    package: "Agentic"
                ),
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
