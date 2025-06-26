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

// MARK: - Random Quote Loader Conformance

extension DummyJSONAPI: Quote.RandomLoader {
  func randomQuote() async throws -> Quote {
    let url = URL(string: "https://dummyjson.com/quotes/random")!
    let (data, _) = try await self.data(for: URLRequest(url: url))
    let quote = try JSONDecoder().decode(DummyJSONQuote.self, from: data)
    return Quote(author: quote.author, content: quote.quote)
  }
}

private struct DummyJSONQuote: Decodable, Sendable {
  let quote: String
  let author: String
}

// MARK: - Recipe IDLoader Conformance

extension DummyJSONAPI: Recipe.IDLoader {
  func recipe(with id: Int) async throws -> Recipe? {
    let url = URL(string: "https://dummyjson.com/recipes/\(id)")!
    let (data, resp) = try await self.data(for: URLRequest(url: url))
    guard resp.statusCode != 404 else { return nil }
    let recipe = try JSONDecoder().decode(DummyJSONRecipe.self, from: data)
    return Recipe(
      id: id,
      name: recipe.name,
      ingredients: recipe.ingredients,
      instructions: recipe.instructions,
      prepTime: Measurement(value: Double(recipe.prepTimeMinutes), unit: .minutes),
      cookTime: Measurement(value: Double(recipe.cookTimeMinutes), unit: .minutes)
    )
  }
}

private struct DummyJSONRecipe: Hashable, Sendable, Codable {
  let id: Int
  let name: String
  let ingredients: [String]
  let instructions: [String]
  let prepTimeMinutes: Int
  let cookTimeMinutes: Int
}

// MARK: - Posts Conformance

extension DummyJSONAPI: Posts {
  func post(with id: Int) async throws -> Post? {
    let url = URL(string: "https://dummyjson.com/posts/\(id)")!
    let (data, resp) = try await self.data(for: URLRequest(url: url))
    guard resp.statusCode != 404 else { return nil }
    let post = try JSONDecoder().decode(DummyJSONPost.self, from: data)
    return Post(
      id: post.id,
      title: post.title,
      content: post.body,
      likeCount: post.reactions.likes,
      isUserLiking: false
    )
  }
}

private struct DummyJSONPost: Decodable, Sendable {
  struct Reactions: Decodable, Sendable {
    let likes: Int
  }
  
  let id: Int
  let title: String
  let body: String
  let reactions: Reactions
}

// MARK: - Helper

extension DummyJSONAPI {
  private func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    try await Task.sleep(for: self.delay)
    let (data, resp) = try await self.transport.data(for: request)
    guard let resp = resp as? HTTPURLResponse else { throw NonHTTPResponseError() }
    return (data, resp)
  }
  
  private struct NonHTTPResponseError: Error {}
}

// MARK: - Shared

extension DummyJSONAPI {
  // NB: The quotes API can be fast, so add some realistic delay.
  static let shared = DummyJSONAPI(
    transport: URLSession.shared,
    delay: .seconds(0.5)
  )
}
