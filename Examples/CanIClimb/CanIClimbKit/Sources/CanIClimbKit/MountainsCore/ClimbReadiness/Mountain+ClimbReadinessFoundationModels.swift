import FoundationModels
import GRDB
import Operation

// MARK: - FoundationModelsGenerator

extension MountainClimbReadiness {
  public final class FoundationModelsGenerator: Generator {
    private let tools: [any Tool]
    private let database: any DatabaseReader

    public init(
      database: any DatabaseReader,
      client: OperationClient,
      vo2MaxLoader: any NumericHealthSamples.Loader,
      stepCounterLoader: any NumericHealthSamples.Loader,
      distanceWalkingRunningLoader: any NumericHealthSamples.Loader
    ) {
      self.database = database
      self.tools = [
        UserLocationTool(client: client).withLogging(),
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
    ) -> any AsyncSequence<GeneratedSegment, any Error> {
      let session = LanguageModelSession(tools: self.tools, instructions: .climbReadiness)
      return AsyncThrowingStream { continuation in
        let task = Task {
          do {
            let humanity = try await self.humanity()
            print("\(Prompt.climbReadiness(for: mountain, humanity: humanity))")
            let stream = session.streamResponse(
              to: .climbReadiness(for: mountain, humanity: humanity),
              generating: MountainClimbReadiness.self
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

    private func humanity() async throws -> UserHumanityGenerable {
      try await self.database.read { db in
        UserHumanityGenerable(record: UserHumanityRecord.find(in: db))
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
      user. Do not state any numerical facts about the user unless you get the numerical fact from \
      a tool.

      Use the 'userLocation' tool to obtain the user's current location, but note that the \
      user may have declined to share their location with you.

      Use the 'currentWeather' tool to obtain the current weather conditions for the mountain, or \
      the user's current location. You will need to provide the mountain's or the user's \
      latitude-longitude coordinate to the tool.

      Use the 'userVO2Max' to obtain the user's vo2max. When using this tool, make sure to \
      invoke it with a duration of at least 6 weeks to be able to get enough samples to identify \
      trends.

      Use the 'userStepCount' tool to obtain the user's step count on a day to day basis.

      Use the 'userDistanceTraveledWalkingRunning' tool to obtain the amount of distance \
      that the user travels each day by walking or running.

      Make sure to always address the user directly, and not from a third person perspective.
      """
    }
  }
}

// MARK: - Prompt

extension Prompt {
  fileprivate static func climbReadiness(
    for mountain: Mountain,
    humanity: UserHumanityGenerable
  ) -> Self {
    Self {
      """
      Asses whether or not the I'm ready to climb the mountain. Make sure to include \
      recommendations for me as well.
      """
      MountainGenerable(mountain: mountain)

      """
      Here is some basic information about me, including my age, gender, and height. My \
      activity level is a self-described measure of how physically active I think I am, so \
      keep that in mind in your assessment.

      DO NOT TELL ME WHAT MY VO2 MAX, STEP COUNT, DAILY DISTANCE TRAVELED, OR WEATHER CONDITIONS \
      ARE IF YOU DID NOT GET THEM BY INVOKING THE APPROPRIATE TOOLS.
      """
      humanity
    }
  }
}
