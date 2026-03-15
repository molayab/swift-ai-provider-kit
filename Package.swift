// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AIProviderKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v11),
        .tvOS(.v26),
        .visionOS(.v2)
    ],
    products: [
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

        // Optional CLI tool — chat with any provider or run live integration tests.
        // swift run runner chat claude | swift run runner test all
        .executable(name: "runner", targets: ["runner"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.63.2")
    ],
    targets: [
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
            dependencies: ["AIProviderKit"],
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
            dependencies: ["AIProviderKit"],
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

        // MARK: - Runner

        .executableTarget(
            name: "runner",
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
                    description: "Run live integration tests via runner. Usage: swift package integration-tests <claude|openai|apple-intelligence|all>"
                ),
                permissions: []
            ),
            dependencies: ["runner"]
        ),

        // MARK: - Tests

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
            dependencies: ["ClaudeProvider", "AIProviderKit"],
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
            dependencies: ["OpenAIProvider", "AIProviderKit"],
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
        )
    ]
)
