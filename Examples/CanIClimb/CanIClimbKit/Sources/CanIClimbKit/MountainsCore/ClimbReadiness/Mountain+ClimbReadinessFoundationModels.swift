import FoundationModels
import GRDB
import Operation

// MARK: - FoundationModelsGenerator

extension Mountain.ClimbReadiness {
  public final class FoundationModelsGenerator: Generator {
    private let tools: [any Tool]

    public init(
      database: any DatabaseReader,
      client: OperationClient,
      vo2MaxLoader: any NumericHealthSamples.Loader,
      stepCounterLoader: any NumericHealthSamples.Loader,
      distanceWalkingRunningLoader: any NumericHealthSamples.Loader
    ) {
      self.tools = [
        UserLocationTool(client: client).withLogging(),
        UserHumanityTool(database: database).withLogging(),
        CurrentWeatherTool(client: client).withLogging(),
        NumericHealthSamplesTool(loader: vo2MaxLoader, client: client)
          .withLogging(),
        NumericHealthSamplesTool(loader: stepCounterLoader, client: client)
          .withLogging(),
        NumericHealthSamplesTool(loader: distanceWalkingRunningLoader, client: client)
          .withLogging()
      ]
    }

    public func readiness(
      for mountain: Mountain
    ) async throws -> any AsyncSequence<GeneratedSegment, any Error> {
      let session = LanguageModelSession(tools: self.tools, instructions: .climbReadiness)
      return AsyncThrowingStream { continuation in
        let task = Task {
          do {
            let stream = session.streamResponse(
              to: .climbReadiness(for: mountain),
              generating: Mountain.ClimbReadiness.self
            )
            for try await snapshot in stream {
              continuation.yield(.partial(snapshot.content))
            }
            let response = try await stream.collect()
            continuation.yield(.full(response.content))
            continuation.finish()
          } catch {
            continuation.finish(throwing: error)
          }
        }
        continuation.onTermination = { _ in task.cancel() }
      }
    }
  }
}

// MARK: - Instructions

extension Instructions {
  fileprivate static var climbReadiness: Self {
    Self {
      """
      You are a hiking instructor evaluating whether or not the user is ready to climb a mountain. \
      Your job is to assess the user's physical fitness and mountain they plan on climbing and \
      give them a readiness rating representing how ready they are to climb the mountain.

      Additionally, you will also want to give them preparation tips for the climb, including \
      preparation climbs, training regiments, nutrition advice, and other advice you deem useful.

      With each request make sure to invoke the tools available to you to learn more about the \
      user.

      Use the 'User Location' tool to obtain the user's current location, but note that the \
      user may have declined to share their location with you.

      Use the 'User Humanity' tool to obtain the user's age, height, weight, gender, activity level, or workout \
      frequency.

      Use the 'Current Weather' tool to obtain the current weather conditions for the mountain, or \
      the user's current location. You will need to provide the mountain's or the user's \
      latitude-longitude coordinate to the tool.

      Use the 'User VO2Max' to obtain the user's vo2max. When using this tool, make sure to \
      invoke it with a duration of at least 6 weeks to be able to get enough samples to identify \
      trends.

      Use the 'User Step Count' tool to obtain the user's step count on a day to day basis.

      Use the 'User Distance Traveled (Walking/Running)' tool to obtain the amount of distance \
      that the user travels each day by walking or running.

      You will receive the mountain data in the following format.

      NAME: <mountain name>
      ELEVATION METERS: <mountain elevation>
      DESCRIPTION: <mountain description>
      LOCATION NAME: <mountain location>
      LAT-LNG COORDINATE: <mountain latitude>, <mountain longitude>
      CLIMBING DIFFICULTY: <mountain climbing difficulty out of 100>
      """
    }
  }
}

// MARK: - Prompt

extension Prompt {
  fileprivate static func climbReadiness(for mountain: Mountain) -> Self {
    Self {
      """
      NAME: \(mountain.name)
      ELEVATION METERS: \(mountain.elevation.converted(to: .meters).formatted(.measurement(width: .abbreviated, usage: .asProvided)))
      DESCRIPTION: \(mountain.displayDescription)
      LOCATION NAME: \(mountain.location.name.localizedStringResource)
      LAT-LNG COORDINATE: \(mountain.location.coordinate.latitude), \(mountain.location.coordinate.longitude)
      CLIMBING DIFFICULTY: \(mountain.difficulty.rawValue) out of 100
      """
    }
  }
}
