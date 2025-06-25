import Foundation
import Query
import Dependencies

// MARK: - Recipe

struct Recipe: Hashable, Sendable, Identifiable {
  let id: Int
  let name: String
  let ingredients: [String]
  let instructions: [String]
  let prepTime: Measurement<UnitDuration>
  let cookTime: Measurement<UnitDuration>
}

// MARK: - Loader

extension Recipe {
  protocol IDLoader: Sendable {
    func recipe(with id: Int) async throws -> Recipe?
  }
}

enum RecipeIDLoaderKey: DependencyKey {
  static let liveValue: any Recipe.IDLoader = DummyJSONAPI.shared
}

// MARK: - Query

extension Recipe {
  static let randomQuery = RandomQuery()
  
  struct RandomQuery: QueryRequest, Hashable {
    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<Recipe?>
    ) async throws -> Recipe? {
      @Dependency(\.withRandomNumberGenerator) var withRNG
      @Dependency(RecipeIDLoaderKey.self) var loader
      let id = withRNG { Int.random(in: 1...50, using: &$0) }
      return try await loader.recipe(with: id)
    }
  }
}
