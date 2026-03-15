import AIProviderKit

// MARK: - Shared error type used by all integration suites

enum IntegrationError: Error, CustomStringConvertible {
    case emptyResponse
    case unexpectedStopReason(StopReason)
    case capabilityUnavailable(String)

    var description: String {
        switch self {
        case .emptyResponse:
            return "Response text was empty"
        case .unexpectedStopReason(let reason):
            return "Unexpected stop reason: \(reason.rawValue)"
        case .capabilityUnavailable(let capability):
            return "Capability '\(capability)' not available on this provider"
        }
    }
}
