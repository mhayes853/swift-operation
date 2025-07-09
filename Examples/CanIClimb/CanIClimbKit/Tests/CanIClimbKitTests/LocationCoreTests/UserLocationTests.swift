import CanIClimbKit
import CustomDump
import Dependencies
import Foundation
import SharingQuery
import Testing

extension DependenciesTestSuite {
  @Suite("UserLocation tests")
  struct UserLocationTests {
    @MainActor
    @Suite("UserLocationQuery tests")
    struct UserLocationQueryTests {
      @Test("Fetches UserLocation When Permission Granted", arguments: [(true, 1), (false, 0)])
      func fetchesUserLocationWhenPermissionGranted(
        isAuthorized: Bool,
        expectedRefetchCount: Int
      ) async throws {
        try await withDependencies {
          let location = MockUserLocation()
          location.currentReading = .success(
            LocationReading(
              coordinate: LocationCoordinate2D(latitude: 0, longitude: 0),
              altitudeAboveSeaLevel: Measurement(value: 10, unit: .meters)
            )
          )
          location.isAuthorized = isAuthorized
          $0[UserLocationKey.self] = location
        } operation: {
          @SharedQuery(LocationReading.userQuery) var userLocation
          @SharedQuery(LocationReading.requestUserPermissionMutation) var request

          _ = try await $userLocation.activeTasks.first?.runIfNeeded()

          expectNoDifference($userLocation.valueUpdateCount, 1)
          _ = try await $request.mutate()
          _ = try await $userLocation.activeTasks.first?.runIfNeeded()
          expectNoDifference($userLocation.valueUpdateCount, 1 + expectedRefetchCount)
        }
      }
    }
  }
}
