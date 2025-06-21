import QueryCore
import Dependencies
import JavaScriptEventLoop

// MARK: - Query

extension NumberFact {
  public static func query(for number: Int) -> some QueryRequest<Self, Query.State> {
    Query(number: number).taskConfiguration { $0.name = "Fetch number fact for \(number)" }
  }

  public struct Query: QueryRequest, Hashable {
    let number: Int

    public func fetch(
      in context: QueryContext, 
      with continuation: QueryContinuation<NumberFact>
    ) async throws -> NumberFact {
      @Dependency(NumberFactLoaderKey.self) var loader
      return try await loader.fact(for: self.number)
    }
  }
}

// MARK: - Nth Prime Query

extension NumberFact {
  public static func nthPrimeQuery(
    for number: Int
  ) -> some QueryRequest<Int?, NthPrimeQuery.State> {
    // NB: Calculating the prime number doesn't need the network, but it still takes 
    // significant time to complete for larger numbers.
    NthPrimeQuery(number: number)
      .completelyOffline()
      .disableApplicationActiveRefetching()
      .taskConfiguration { 
        @Dependency(WebWorkerTaskExecutorKey.self) var executor
        $0.name = "Nth prime for \(number)" 
        $0.executorPreference = executor
      }
  }

  public struct NthPrimeQuery: QueryRequest, Hashable {
    let number: Int

    public func fetch(
      in context: QueryContext, 
      with continuation: QueryContinuation<Int?>
    ) async throws -> Int? {
      await nthPrime(for: self.number)
    }
  }
}

// MARK: - Loader DependencyKey

public enum NumberFactLoaderKey: DependencyKey {
  public static let liveValue: any NumberFact.Loader = NumberFact.APILoader()
}