import CoreLocation
import MapKit

/// A ready-to-use `Tool` that provides the device's current location to the model.
///
/// Add this to your `ToolRegistry` or pass it directly in `AIRequest.tools`.
/// The user will be prompted for location permission on first use.
///
/// ```swift
/// await client.toolRegistry.register(LocationTool.make())
/// ```
public enum LocationTool: ToolGroup {

    /// All provided location tools.
    public static var all: [Tool] { [make()] }

    public static func make() -> Tool {
        Tool(
            name: "get_current_location",
            description: "Returns the device's current GPS coordinates and optional address.",
            inputSchema: .object(
                properties: [
                    "includeAddress": .boolean(
                        description: "Whether to reverse-geocode coordinates into a human-readable address. Default: false."
                    )
                ]
            )
        ) { input async throws in
            let includeAddress = input["includeAddress"]?.boolValue ?? false
            let location = try await LocationTool.fetchLocation()

            var result: [String: JSONValue] = [
                "latitude": .double(location.coordinate.latitude),
                "longitude": .double(location.coordinate.longitude),
                "accuracy": .double(location.horizontalAccuracy)
            ]

            if includeAddress {
                if let address = try? await LocationTool.reverseGeocode(location) {
                    result["address"] = .string(address)
                }
            }

            return .object(result)
        }
    }

    // MARK: - Private helpers

    private static func fetchLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = SingleLocationDelegate(continuation: continuation)
            let manager = CLLocationManager()
            manager.delegate = delegate
            manager.desiredAccuracy = kCLLocationAccuracyBest
            #if os(tvOS)
            manager.requestAlwaysAuthorization()
            #else
            manager.requestWhenInUseAuthorization()
            #endif
            manager.requestLocation()
            // Keep delegate alive during the async operation.
            _ = delegate
        }
    }

    private static func reverseGeocode(_ location: CLLocation) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            guard let request = MKReverseGeocodingRequest(location: location) else {
                continuation.resume(returning: "")
                return
            }
            request.getMapItems { items, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let address = items?.first?.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true) ?? ""
                continuation.resume(returning: address)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate helper

private final class SingleLocationDelegate: NSObject, CLLocationManagerDelegate, Sendable {

    private let continuation: CheckedContinuation<CLLocation, any Error>

    init(continuation: CheckedContinuation<CLLocation, any Error>) {
        self.continuation = continuation
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        continuation.resume(returning: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        continuation.resume(throwing: error)
    }
}
