// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AIProviderKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "AIProviderKitNetworking",
            targets: ["AIProviderKitNetworking"]
        ),
        .library(
            name: "AIProviderKit",
            targets: ["AIProviderKit"]
        ),
        .library(
            name: "ClaudeProvider",
            targets: ["ClaudeProvider"]
        ),
        .library(
            name: "OpenAIProvider",
            targets: ["OpenAIProvider"]
        ),
        // Apple Intelligence (on-device inference, iOS 26+ / macOS 26+)
        .library(name: "AppleIntelligenceProvider", targets: ["AppleIntelligenceProvider"]),

        // Ready-to-use Tool implementations anyone can drop into an AIClient.
        .library(name: "AIProviderTools", targets: ["AIProviderTools"]),

        // SwiftData-backed conversation persistence (Apple platforms only).
        .library(name: "AIProviderKitPersistence", targets: ["AIProviderKitPersistence"]),

        // Optional CLI tool — chat with any provider or run live integration tests.
        // swift run Runner chat claude | swift run Runner test all
        .executable(name: "Runner", targets: ["Runner"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.63.2")
    ],
    targets: [
        // MARK: - Networking

        .target(
            name: "AIProviderKitNetworking",
            path: "Sources/AIProviderKitNetworking",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),

        // MARK: - Core

        .target(
            name: "AIProviderKit",
            path: "Sources/AIProviderKit",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),

        // MARK: - Claude

        .target(
            name: "ClaudeProvider",
            dependencies: ["AIProviderKit", "AIProviderKitNetworking"],
            path: "Sources/ClaudeProvider",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),

        // MARK: - OpenAI

        .target(
            name: "OpenAIProvider",
            dependencies: ["AIProviderKit", "AIProviderKitNetworking"],
            path: "Sources/OpenAIProvider",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),

        // MARK: - Apple Intelligence (Foundation Models)

        .target(
            name: "AppleIntelligenceProvider",
            dependencies: ["AIProviderKit"],
            path: "Sources/AppleIntelligenceProvider",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),

        // MARK: - AIProviderTools

        .target(
            name: "AIProviderTools",
            dependencies: ["AIProviderKit"],
            path: "Sources/AIProviderTools",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),

        // MARK: - Persistence (SwiftData)

        .target(
            name: "AIProviderKitPersistence",
            dependencies: ["AIProviderKit"],
            path: "Sources/AIProviderKitPersistence",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),

        // MARK: - Runner

        .executableTarget(
            name: "Runner",
            dependencies: ["AIProviderKit", "AIProviderTools", "ClaudeProvider", "OpenAIProvider", "AppleIntelligenceProvider"],
            path: "Sources/runner",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .plugin(
            name: "RunIntegrationTests",
            capability: .command(
                intent: .custom(
                    verb: "integration-tests",
                    description: "Run live integration tests via Runner. Usage: swift package integration-tests <claude|openai|apple-intelligence|all>"
                ),
                permissions: []
            ),
            dependencies: ["Runner"]
        ),

        // MARK: - Tests

        .testTarget(
            name: "AIProviderKitNetworkingTests",
            dependencies: ["AIProviderKitNetworking"],
            path: "Tests/AIProviderKitNetworkingTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "AIProviderKitTests",
            dependencies: ["AIProviderKit"],
            path: "Tests/AIProviderKitTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "ClaudeProviderTests",
            dependencies: ["ClaudeProvider", "AIProviderKit", "AIProviderKitNetworking"],
            path: "Tests/ClaudeProviderTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "AppleIntelligenceProviderTests",
            dependencies: ["AppleIntelligenceProvider", "AIProviderKit"],
            path: "Tests/AppleIntelligenceProviderTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "OpenAIProviderTests",
            dependencies: ["OpenAIProvider", "AIProviderKit", "AIProviderKitNetworking"],
            path: "Tests/OpenAIProviderTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "AIProviderToolsTests",
            dependencies: ["AIProviderTools", "AIProviderKit"],
            path: "Tests/AIProviderToolsTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "AIProviderKitPersistenceTests",
            dependencies: ["AIProviderKitPersistence", "AIProviderKit"],
            path: "Tests/AIProviderKitPersistenceTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        )
    ]
)
