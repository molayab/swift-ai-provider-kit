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
        // Post-MVP: OpenAI support
        // .library(name: "OpenAIProvider", targets: ["OpenAIProvider"]),
        //
        // Apple Intelligence (on-device inference, iOS 26+ / macOS 26+)
        .library(name: "AppleIntelligenceProvider", targets: ["AppleIntelligenceProvider"]),

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

        // MARK: - Apple Intelligence (Foundation Models)

        .target(
            name: "AppleIntelligenceProvider",
            dependencies: ["AIProviderKit"],
            path: "Sources/AppleIntelligenceProvider",
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
            name: "AppleIntelligenceProviderTests",
            dependencies: ["AppleIntelligenceProvider", "AIProviderKit"],
            path: "Tests/AppleIntelligenceProviderTests",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
