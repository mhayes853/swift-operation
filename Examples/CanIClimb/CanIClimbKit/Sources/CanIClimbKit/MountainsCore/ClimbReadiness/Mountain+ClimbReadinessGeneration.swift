import CasePaths
import Dependencies
import FoundationModels
import SQLiteData
import SharingOperation

// MARK: - GeneratedSegment

extension Mountain.ClimbReadiness {
  @CasePathable
  public enum GeneratedSegment: Hashable, Sendable {
    case empty
    case partial(Mountain.ClimbReadiness.PartiallyGenerated)
    case full(Mountain.ClimbReadiness)
  }
}

// MARK: - Generator

extension Mountain.ClimbReadiness {
  public protocol Generator: Sendable {
    func readiness(for mountain: Mountain) -> any AsyncSequence<GeneratedSegment, any Error>
  }

  public enum GeneratorKey: DependencyKey {
    public static var liveValue: any Generator {
      @Dependency(\.defaultDatabase) var database
      @Dependency(\.defaultOperationClient) var client
      return FoundationModelsGenerator(
        database: database,
        client: client,
        vo2MaxLoader: NumericHealthSamples.HKLoader(kind: .vo2Max),
        stepCounterLoader: NumericHealthSamples.HKLoader(kind: .stepCount),
        distanceWalkingRunningLoader: NumericHealthSamples.HKLoader(
          kind: .distanceWalkingRunningMeters
        )
      )
    }
  }
}

extension Mountain.ClimbReadiness {
  @MainActor
  public final class MockGenerator: Generator {
    public var segments = [GeneratedSegment]()
    public var shouldFail = false

    public init(segments: [GeneratedSegment]) {
      self.segments = segments
    }

    public nonisolated func readiness(
      for mountain: Mountain
    ) -> any AsyncSequence<GeneratedSegment, any Error> {
      AsyncThrowingStream { continuation in
        Task {
          guard !(await self.shouldFail) else {
            continuation.finish(throwing: SomeError())
            return
          }
          for segment in await self.segments {
            continuation.yield(segment)
          }
          continuation.finish()
        }
      }
    }

    private struct SomeError: Error {}
  }
}

// MARK: - Query

extension Mountain.ClimbReadiness {
  public static func generationQuery(
    for mountain: Mountain
  ) -> some QueryRequest<GeneratedSegment, any Error> {
    GenerationQuery(mountain: mountain)
      .disableApplicationActiveRerunning()
      .satisfiedConnectionStatus(.disconnected)
  }

  public struct GenerationQuery: QueryRequest, Hashable {
    let mountain: Mountain

    public func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<GeneratedSegment, any Error>
    ) async throws -> GeneratedSegment {
      @Dependency(Mountain.ClimbReadiness.GeneratorKey.self) var generator: any Generator

      var context = context
      context.operationClock = context.operationClock.frozen()

      var currentSegment = GeneratedSegment.empty
      for try await segment in generator.readiness(for: self.mountain) {
        currentSegment = segment
        continuation.yield(currentSegment, using: context)
      }
      return currentSegment
    }
  }
}
