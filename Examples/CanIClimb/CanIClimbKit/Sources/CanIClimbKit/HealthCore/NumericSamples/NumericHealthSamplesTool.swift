import Foundation
import FoundationModels
import Operation

public struct NumericHealthSamplesTool: Tool {
  @Generable
  public struct Arguments: Sendable {
    @Guide(
      description:
        "A query for the timeframe to get samples from. (eg. 'last 10 days', 'last 3 weeks')",
      NumericHealthSamples.Request.queryRegex
    )
    public let query: String
  }

  private let loader: any NumericHealthSamples.Loader
  private let client: OperationClient

  public var name: String {
    switch self.loader.kind {
    case .distanceWalkingRunningMeters: "userDistanceTraveledWalkingRunning"
    case .stepCount: "userStepCount"
    case .vo2Max: "userVO2Max"
    }
  }

  public var description: String {
    switch self.loader.kind {
    case .distanceWalkingRunningMeters:
      """
      Provides the distance (in meters) traveled by the user during walking or running activities. \
      Use this as a measure of physical activity intensity.
      """
    case .stepCount:
      """
      Provides the number of steps taken by the user on a day to day basis. \
      Use this as a measure of physical activity frequency.
      """
    case .vo2Max:
      """
      Provides VO2 Max samples from the user's health data. \
      Use this to determine their cardio fitness level.
      """
    }
  }

  public init(loader: any NumericHealthSamples.Loader, client: OperationClient) {
    self.loader = loader
    self.client = client
  }

  public func call(arguments: Arguments) async throws -> NumericHealthSamples {
    let store = self.client.store(
      for: NumericHealthSamples.query(
        for: NumericHealthSamples.Request(query: arguments.query),
        using: self.loader
      )
    )
    return try await store.fetch()
  }
}
