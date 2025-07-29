import CoreLocation

// MARK: - CLUserLocation

@MainActor
public final class CLUserLocation: NSObject {
  private var manager: CLLocationManager
  private var permissionContinutations = [UnsafeContinuation<Bool, Never>]()
  private var coordinateContinuations = [UnsafeContinuation<LocationReading, Error>]()

  override public init() {
    self.manager = CLLocationManager()
    super.init()
    self.manager.delegate = self
  }
}

// MARK: - UserLocation Conformance

extension CLUserLocation: UserLocation {
  public func requestAuthorization() async -> Bool {
    await withUnsafeContinuation { continuation in
      self.permissionContinutations.append(continuation)
      self.manager.requestWhenInUseAuthorization()
    }
  }

  public func read() async throws -> LocationReading {
    try await withUnsafeThrowingContinuation { continuation in
      self.coordinateContinuations.append(continuation)
      self.manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
      self.manager.requestLocation()
    }
  }
}

// MARK: - CLLocationManagerDelegate

extension CLUserLocation: CLLocationManagerDelegate {
  public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard manager.authorizationStatus != .notDetermined else { return }
    #if os(iOS)
      let isAuthorized = manager.authorizationStatus == .authorizedWhenInUse
    #else
      let isAuthorized = manager.authorizationStatus == .authorized
    #endif
    Task {
      await self.resumePermissionsRequest(with: isAuthorized)
    }
  }

  private func resumePermissionsRequest(with status: Bool) {
    for continuation in self.permissionContinutations {
      continuation.resume(returning: status)
    }
    self.permissionContinutations.removeAll()
  }

  public nonisolated func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    guard let location = locations.first else { return }
    let reading = LocationReading(location: location)
    Task { await self.resumeCoordinateFetch(with: reading) }
  }

  private func resumeCoordinateFetch(with reading: LocationReading) {
    for continuation in self.coordinateContinuations {
      continuation.resume(returning: reading)
    }
    self.coordinateContinuations.removeAll()
  }

  public nonisolated func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: Error
  ) {
    Task { await self.failCoordinateFetch(with: error) }
  }

  private func failCoordinateFetch(with error: any Error) {
    for continuation in self.coordinateContinuations {
      continuation.resume(throwing: error)
    }
    self.coordinateContinuations.removeAll()
  }
}
