import CanIClimbKit
import CustomDump
import Dependencies
import Foundation
import XCTest

@MainActor
final class MountainTravelEstimatesModelTests: XCTestCase {
  func testFetchesEstimatesWhenUserLocationChanges() async throws {
    try await withDependencies {
      let userLocation = MockUserLocation()
      userLocation.currentReading = .success(
        LocationReading(
          coordinate: .everest,
          altitudeAboveSeaLevel: Measurement(value: 30_000, unit: .feet)
        )
      )
      $0[UserLocationKey.self] = userLocation

      let loader = TravelEstimate.MockLoader()
      for type in TravelType.allCases {
        let expectedRequest = TravelEstimate.Request(
          travelType: type,
          origin: .everest,
          destination: Mountain.mock1.location.coordinate
        )
        loader.results[expectedRequest] = .success(.mock(for: type))
      }
      $0[TravelEstimate.LoaderKey.self] = loader
    } operation: {
      let model = MountainTravelEstimatesModel(mountain: .mock1)
      try await model.$userLocation.load()

      for type in TravelType.allCases {
        _ = try await model.estimates[type]?.activeTasks.first?.runIfNeeded()
        expectNoDifference(model.estimates[type]?.wrappedValue, .mock(for: type))
      }

      let expectation = self.expectation(description: "Updates travel estimated")
      model.onUserLocationChanged = {
        for type in TravelType.allCases {
          expectNoDifference(model.estimates[type], nil)
        }
        expectation.fulfill()
      }
      model.$userLocation.withLock { $0 = nil }
      await self.fulfillment(of: [expectation], timeout: 1)
    }
  }
}
