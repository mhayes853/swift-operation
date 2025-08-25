import Dependencies
import Foundation
import Operation

// MARK: - Quote

struct Quote: Hashable, Sendable {
  let author: String
  let content: String
}

// MARK: - Random Loader

extension Quote {
  protocol RandomLoader: Sendable {
    func randomQuote() async throws -> Quote
  }
}

enum QuoteRandomLoaderKey: DependencyKey {
  static let liveValue: any Quote.RandomLoader = DummyJSONAPI.shared
}

// MARK: - Mock Loader

extension Quote {
  struct MockRandomLoader: RandomLoader {
    var result: Result<Quote, any Error>
    var delay = Duration.zero

    func randomQuote() async throws -> Quote {
      try await Task.sleep(for: self.delay)
      return try self.result.get()
    }
  }
}

// MARK: - Random Query

extension Quote {
  static let randomQuery = RandomQuery()

  struct RandomQuery: QueryRequest, Hashable {
    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<Quote>
    ) async throws -> Quote {
      @Dependency(QuoteRandomLoaderKey.self) var loader
      return try await loader.randomQuote()
    }
  }
}
