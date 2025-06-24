import Foundation
import Dependencies

// MARK: - DummyJSONAPI API

final class DummyJSONAPI: Sendable {
  private let transport: any HTTPDataTransport
  private let delay: Duration
  
  init(transport: any HTTPDataTransport, delay: Duration = .zero) {
    self.transport = transport
    self.delay = delay
  }
}

// MARK: - Random Loader Conformance

extension DummyJSONAPI: Quote.RandomLoader {
  func randomQuote() async throws -> Quote {
    try await Task.sleep(for: self.delay)
    let url = URL(string: "https://dummyjson.com/quotes/random")!
    let (data, _) = try await self.transport.data(for: URLRequest(url: url))
    let quote = try JSONDecoder().decode(DummyJSONQuote.self, from: data)
    return Quote(author: quote.author, content: quote.quote)
  }
}

private struct DummyJSONQuote: Decodable, Sendable {
  let quote: String
  let author: String
}

// MARK: - Shared

extension DummyJSONAPI {
  // NB: The quotes API can be fast, so add some realistic delay.
  static let shared = DummyJSONAPI(
    transport: URLSession.shared,
    delay: .seconds(0.2)
  )
}
