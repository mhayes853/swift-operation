import Dependencies
import FoundationModels
import Operation

// MARK: - Generator

extension Mountain.ClimbReadiness {
  public enum GeneratedSegment: Hashable, Sendable {
    case empty
    case partial(Mountain.ClimbReadiness.PartiallyGenerated)
    case full(Mountain.ClimbReadiness)
  }

  public protocol Generator: Sendable {
    func readiness(
      for mountain: Mountain
    ) async throws -> any AsyncSequence<GeneratedSegment, any Error>
  }

  public enum GeneratorKey: DependencyKey {
    public static var liveValue: any Generator {
      fatalError()
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
    ) async throws -> any AsyncSequence<Mountain.ClimbReadiness.GeneratedSegment, any Error> {
      if await self.shouldFail {
        throw SomeError()
      }
      let segments = await self.segments
      return AsyncThrowingStream {
        for segment in segments {
          $0.yield(segment)
        }
        $0.finish()
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
  }

  public struct GenerationQuery: QueryRequest, Hashable {
    let mountain: Mountain

    public func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<GeneratedSegment, any Error>
    ) async throws -> GeneratedSegment {
      @Dependency(Mountain.ClimbReadiness.GeneratorKey.self) var generator: any Generator
      var segment = GeneratedSegment.empty
      for try await s in try await generator.readiness(for: self.mountain) {
        segment = s
        continuation.yield(segment)
      }
      return segment
    }
  }
}
