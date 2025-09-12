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
    case .distanceWalkingRunningMeters: "User Distance Traveled (Walking/Running)"
    case .stepCount: "User Step Count"
    case .vo2Max: "User VO2 Max"
    }
  }

  public var description: String {
    switch self.loader.kind {
    case .distanceWalkingRunningMeters:
      "Provides the distance (in meters) traveled by the user during walking or running activities."
    case .stepCount: "Provides the number of steps taken by the user on a day to day basis."
    case .vo2Max: "Provides VO2 Max samples from the user's health data."
    }
  }

  public init(loader: any NumericHealthSamples.Loader, client: OperationClient) {
    self.loader = loader
    self.client = client
  }

  public func call(arguments: Arguments) async throws -> NumericHealthSamples.Response {
    let store = self.client.store(
      for: NumericHealthSamples.query(
        for: NumericHealthSamples.Request(query: arguments.query),
        using: self.loader
      )
    )
    return try await store.fetch()
  }
}
