import CanIClimbKit
import CustomDump
import Dependencies
import Foundation
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("MountainTravelEstimatesModel tests")
  struct MountainTravelEstimatedModelTests {
    @Test("Fetches Estimates When User Location Changes")
    func fetchesEstimatesWhenUserLocationChanges() async throws {
      struct SomeError: Error {}

      try await withDependencies {
        $0[UserLocationKey.self] = MockUserLocation()

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
        let reading = LocationReading(
          coordinate: .everest,
          altitudeAboveSeaLevel: Measurement(value: 0, unit: .meters)
        )

        let model = MountainTravelEstimatesModel(mountain: .mock1)
        model.userLocationUpdated(reading: .success(reading))

        for type in TravelType.allCases {
          _ = try await model.estimates[type]?.activeTasks.first?.runIfNeeded()
          expectNoDifference(model.estimates[type]?.wrappedValue, .mock(for: type))
        }

        model.userLocationUpdated(reading: .failure(SomeError()))
        for type in TravelType.allCases {
          expectNoDifference(model.estimates[type], nil)
        }
      }
    }
  }
}
