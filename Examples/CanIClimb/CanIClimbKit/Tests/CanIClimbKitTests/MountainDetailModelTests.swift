import CanIClimbKit
import CustomDump
import Dependencies
import Query
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("MountainDetailModelTests")
  struct MountainDetailModelTests {
    @Test("Mountain Loading Sets Travel Estimate And Weather Models")
    func mountainLoadingSetsTravelEstimateAndWeatherModels() async throws {
      try await withModelsDerivationTest { ctx in
        ctx.model.detailsUpdated(
          mountainStatus: .result(.success(.mock1)),
          userLocationStatus: .loading
        )

        let weatherModel = try #require(ctx.model.weather)
        _ = try await weatherModel.mountainWeatherDetail.reading?.activeTasks.first?.runIfNeeded()
        expectNoDifference(
          weatherModel.mountainWeatherDetail.reading?.wrappedValue,
          .mock(location: ctx.mountainLocation)
        )

        expectNoDifference(ctx.model.travelEstimates?.mountain, .mock1)
      }
    }

    @Test("Does Not Update Travel Estimate Or Weather Models When No Mountain Loaded")
    func doesNotUpdateTravelEstimateOrWeatherModelsWhenNoMountainLoaded() async throws {
      try await withModelsDerivationTest { ctx in
        ctx.model.detailsUpdated(
          mountainStatus: .loading,
          userLocationStatus: .result(.success(ctx.userLocation))
        )
        expectNoDifference(ctx.model.weather == nil, true)
        expectNoDifference(ctx.model.travelEstimates == nil, true)
      }
    }

    @Test("Uses User Location Update When Mountain Loads")
    func usesUserLocationUpdateWhenMountainLoads() async throws {
      try await withModelsDerivationTest { ctx in
        ctx.model.detailsUpdated(
          mountainStatus: .result(.success(.mock1)),
          userLocationStatus: .result(.success(ctx.userLocation))
        )

        let weatherModel = try #require(ctx.model.weather)
        _ = try await weatherModel.mountainWeatherDetail.reading?.activeTasks.first?.runIfNeeded()
        expectNoDifference(
          weatherModel.mountainWeatherDetail.reading?.wrappedValue,
          .mock(location: ctx.mountainLocation)
        )

        _ = try await weatherModel.userWeatherDetail.reading?.load()
        expectNoDifference(
          weatherModel.userWeatherDetail.reading?.wrappedValue,
          .mock(location: ctx.userLocation)
        )

        let travelEstimatesModel = try #require(ctx.model.travelEstimates)
        for type in TravelType.allCases {
          _ = try await travelEstimatesModel.estimates[type]?.activeTasks.first?.runIfNeeded()
          expectNoDifference(travelEstimatesModel.estimates[type]?.wrappedValue, .mock(for: type))
        }
      }
    }

    @Test("Does Not Reset Travel Estimates and Weather When Mountain Does Not Change")
    func doesNotResetTravelEstimatesAndWeatherWhenMountainDoesNotChange() async throws {
      try await withModelsDerivationTest { ctx in
        ctx.model.detailsUpdated(
          mountainStatus: .result(.success(.mock1)),
          userLocationStatus: .loading
        )

        let weatherModel = try #require(ctx.model.weather)
        let travelEstimatesModel = try #require(ctx.model.travelEstimates)

        ctx.model.detailsUpdated(
          mountainStatus: .result(.success(.mock1)),
          userLocationStatus: .result(.success(.mock()))
        )

        expectNoDifference(weatherModel === ctx.model.weather, true)
        expectNoDifference(travelEstimatesModel === ctx.model.travelEstimates, true)
      }
    }

    @Test("Resets Weather And Travel Estimates When Mountain Changes")
    func resetsWeatherAndTravelEstimatesWhenMountainChanges() async throws {
      try await withModelsDerivationTest { ctx in
        ctx.model.detailsUpdated(
          mountainStatus: .result(.success(.mock1)),
          userLocationStatus: .loading
        )
        ctx.model.detailsUpdated(
          mountainStatus: .result(.success(nil)),
          userLocationStatus: .result(.success(.mock()))
        )
        expectNoDifference(ctx.model.weather == nil, true)
        expectNoDifference(ctx.model.travelEstimates == nil, true)
      }
    }

    @Test("Keeps Existing Weather And Travel Estimates When Mountain Is Loading")
    func keepsExistingWeatherAndTravelEstimatesWhenMountainIsLoading() async throws {
      try await withModelsDerivationTest { ctx in
        ctx.model.detailsUpdated(
          mountainStatus: .result(.success(.mock1)),
          userLocationStatus: .loading
        )
        ctx.model.detailsUpdated(mountainStatus: .loading, userLocationStatus: .loading)
        expectNoDifference(ctx.model.weather != nil, true)
        expectNoDifference(ctx.model.travelEstimates != nil, true)
      }
    }

    @Test("Clears Weather And Travel Estimates When Mountain Fails To Load")
    func clearsWeatherAndTravelEstimatesWhenMountainFailsToLoad() async throws {
      struct SomeError: Error {}
      try await withModelsDerivationTest { ctx in
        ctx.model.detailsUpdated(
          mountainStatus: .result(.success(.mock1)),
          userLocationStatus: .loading
        )
        ctx.model.detailsUpdated(
          mountainStatus: .result(.failure(SomeError())),
          userLocationStatus: .loading
        )
        expectNoDifference(ctx.model.weather == nil, true)
        expectNoDifference(ctx.model.travelEstimates == nil, true)
      }
    }

    @Test("Clears Weather And Travel Estimates When Mountain Not Found")
    func clearsWeatherAndTravelEstimatesWhenMountainNotFound() async throws {
      try await withModelsDerivationTest { ctx in
        ctx.model.detailsUpdated(
          mountainStatus: .result(.success(.mock1)),
          userLocationStatus: .loading
        )
        ctx.model.detailsUpdated(
          mountainStatus: .result(.success(nil)),
          userLocationStatus: .loading
        )
        expectNoDifference(ctx.model.weather == nil, true)
        expectNoDifference(ctx.model.travelEstimates == nil, true)
      }
    }
  }
}

private struct ModelsDerivationContext {
  let model: MountainDetailModel
  let userLocation: LocationReading
  let mountainLocation: LocationReading
}

@MainActor
private func withModelsDerivationTest(
  _ fn: @MainActor @Sendable (ModelsDerivationContext) async throws -> Void
) async throws {
  let userLocation = LocationReading.mock()
  let mountainLocation = LocationReading.mock(coordinate: Mountain.mock1.location.coordinate)
  try await withDependencies {
    $0[UserLocationKey.self] = MockUserLocation()
    $0[Mountain.LoaderKey.self] = Mountain.MockLoader(result: .success(.mock1))

    let weather = WeatherReading.MockCurrentReader()
    weather.results[Mountain.mock1.location.coordinate] = .success(
      .mock(location: mountainLocation)
    )
    weather.results[userLocation.coordinate] = .success(.mock(location: userLocation))
    $0[WeatherReading.CurrentReaderKey.self] = weather

    let loader = TravelEstimate.MockLoader()
    for type in TravelType.allCases {
      let expectedRequest = TravelEstimate.Request(
        travelType: type,
        origin: userLocation.coordinate,
        destination: Mountain.mock1.location.coordinate
      )
      loader.results[expectedRequest] = .success(.mock(for: type))
    }
    $0[TravelEstimate.LoaderKey.self] = loader

    $0[Mountain.PlannedClimbsLoaderKey.self] = Mountain.MockPlannedClimbsLoader()
  } operation: {
    let model = MountainDetailModel(id: Mountain.mock1.id)
    let context = ModelsDerivationContext(
      model: model,
      userLocation: userLocation,
      mountainLocation: mountainLocation
    )
    try await fn(context)
  }
}
