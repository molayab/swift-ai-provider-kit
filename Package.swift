// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AIProviderKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
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
            name: "AIProviderKitUI",
            targets: ["AIProviderKitUI"]
        ),
        // Post-MVP: OpenAI support
        // .library(name: "OpenAIProvider", targets: ["OpenAIProvider"]),
        //
        // Post-MVP: Apple Foundation Models (on-device inference, iOS 26+)
        // .library(name: "FoundationModelProvider", targets: ["FoundationModelProvider"]),

        // Integration test runner (not part of the library)
        .executable(name: "IntegrationTests", targets: ["IntegrationTests"]),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint", from: "0.63.2")
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
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
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
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
        ),

        // Post-MVP: OpenAI
        // .target(name: "OpenAIProvider", dependencies: ["AIProviderKit"], path: "Sources/OpenAIProvider"),

        // Post-MVP: Apple Foundation Models
        // .target(name: "FoundationModelProvider", dependencies: ["AIProviderKit"], path: "Sources/FoundationModelProvider"),

        // MARK: - UI

        .target(
            name: "AIProviderKitUI",
            dependencies: ["AIProviderKit"],
            path: "Sources/AIProviderKitUI",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
        ),

        // MARK: - Integration Tests

        .executableTarget(
            name: "IntegrationTests",
            dependencies: ["AIProviderKit", "ClaudeProvider"],
            path: "Sources/IntegrationTests",
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
                    description: "Run live integration tests against AI providers. Set ANTHROPIC_API_KEY before running."
                ),
                permissions: []
            ),
            dependencies: ["IntegrationTests"]
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
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
        ),
        .testTarget(
            name: "ClaudeProviderTests",
            dependencies: ["ClaudeProvider", "AIProviderKit"],
            path: "Tests/ClaudeProviderTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
        )
    ]
)
