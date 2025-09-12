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
      You are a hiking instructor evaluating whether or not a person is ready to climb a mountain. \
      Your job is to assess the person's physical fitness and mountain they plan on climbing and \
      give them a numerical score out of 100 representing how ready they are to climb the mountain.

      Additionally, you will also want to give them preparation tips for the climb, including \
      preparation climbs, workouts, and other general fitness advice.

      If you need the person's current location, use the 'User Location' tool, but note that the \
      user may have declined to share their location with you.

      If you need to know the person's age, height, weight, gender, activity level, or workout \
      frequency, use the 'User Humanity' tool.

      If you need to obtain the current weather conditions for the mountain, or the person's \
      current location, use the 'Current Weather' tool. You will need to provide the mountain's \
      or the person's latitude-longitude coordinate.

      If you want to obtain the person's cardio fitness level, use the 'User VO2Max' tool. When \
      using this tool, make sure to invoke it with a duration of at least 6 weeks to be able to get \
      enough samples to identify trends.

      If you want to obtain the person's step count on a day to day basis, use the \
      'User Step Count' tool.

      If you want to obtain the amount of distance that the person travels each day by walking or \
      running, use the 'User Distance Traveled (Walking/Running)' tool.

      You will receive the mountain data in the following format.

      <mountain name>
      <mountain elevation (meters)>
      <mountain description>
      <mountain location>
      <mountain latitude>, <mountain longitude>
      <mountain climbing difficulty out of 100>
      """
    }
  }
}

// MARK: - Prompt

extension Prompt {
  fileprivate static func climbReadiness(for mountain: Mountain) -> Self {
    Self {
      """
      \(mountain.name)
      \(mountain.elevation.converted(to: .meters).formatted(.measurement(width: .abbreviated, usage: .asProvided)))
      \(mountain.displayDescription)
      \(mountain.location.name.localizedStringResource)
      \(mountain.location.coordinate.latitude), \(mountain.location.coordinate.longitude)
      \(mountain.difficulty.rawValue) out of 100
      """
    }
  }
}
