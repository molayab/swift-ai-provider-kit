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
        // Apple Foundation Models (on-device inference, iOS 18.1+ / macOS 15.1+)
        .library(name: "FoundationModelProvider", targets: ["FoundationModelProvider"]),

        // Integration test runner (not part of the library)
        .executable(name: "IntegrationTests", targets: ["IntegrationTests"]),
    ],
    targets: [
        // MARK: - Core

        .target(
            name: "AIProviderKit",
            path: "Sources/AIProviderKit",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),

        // MARK: - Claude

        .target(
            name: "ClaudeProvider",
            dependencies: ["AIProviderKit"],
            path: "Sources/ClaudeProvider",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),

        // Post-MVP: OpenAI
        // .target(name: "OpenAIProvider", dependencies: ["AIProviderKit"], path: "Sources/OpenAIProvider"),

        // MARK: - Foundation Models

        .target(
            name: "FoundationModelProvider",
            dependencies: ["AIProviderKit"],
            path: "Sources/FoundationModelProvider",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),

        // MARK: - UI

        .target(
            name: "AIProviderKitUI",
            dependencies: ["AIProviderKit"],
            path: "Sources/AIProviderKitUI",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
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
            ]
        ),
        .testTarget(
            name: "ClaudeProviderTests",
            dependencies: ["ClaudeProvider", "AIProviderKit"],
            path: "Tests/ClaudeProviderTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "FoundationModelProviderTests",
            dependencies: ["FoundationModelProvider", "AIProviderKit"],
            path: "Tests/FoundationModelProviderTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
