import CustomDump
import Dependencies
import Foundation
import SharingOperation
import Testing

@testable import CaseStudies

@Suite("Recipe+Query tests")
struct RecipeQueryTests {
  @Test("Loads Random Recipe From Dummy JSON")
  func loadsRandomRecipeFromDummyJSON() async throws {
    let json = """
      {
        "id": 1,
        "name": "Classic Margherita Pizza",
        "ingredients": [
          "Pizza dough",
          "Tomato sauce",
          "Fresh mozzarella cheese",
          "Fresh basil leaves",
          "Olive oil",
          "Salt and pepper to taste"
        ],
        "instructions": [
          "Preheat the oven to 475°F (245°C).",
          "Roll out the pizza dough and spread tomato sauce evenly.",
          "Top with slices of fresh mozzarella and fresh basil leaves.",
          "Drizzle with olive oil and season with salt and pepper.",
          "Bake in the preheated oven for 12-15 minutes or until the crust is golden brown.",
          "Slice and serve hot."
        ],
        "prepTimeMinutes": 20,
        "cookTimeMinutes": 15,
        "servings": 4,
        "difficulty": "Easy",
        "cuisine": "Italian",
        "caloriesPerServing": 300,
        "tags": [
          "Pizza",
          "Italian"
        ],
        "userId": 166,
        "image": "https://cdn.dummyjson.com/recipe-images/1.webp",
        "rating": 4.6,
        "reviewCount": 98,
        "mealType": [
          "Dinner"
        ]
      }
      """

    let transport = MockHTTPDataTransport { request in
      guard request.url?.path() == "/recipes/1" else { return (404, .data(Data())) }
      return (200, .data(Data(json.utf8)))
    }
    try await withDependencies {
      $0.withRandomNumberGenerator = WithRandomNumberGenerator(OneGenerator())
      $0[RecipeIDLoaderKey.self] = DummyJSONAPI(transport: transport)
    } operation: {
      @SharedOperation(Recipe.$randomQuery) var recipe
      try await $recipe.load()

      let expectedRecipe = Recipe(
        id: 1,
        name: "Classic Margherita Pizza",
        ingredients: [
          "Pizza dough",
          "Tomato sauce",
          "Fresh mozzarella cheese",
          "Fresh basil leaves",
          "Olive oil",
          "Salt and pepper to taste"
        ],
        instructions: [
          "Preheat the oven to 475°F (245°C).",
          "Roll out the pizza dough and spread tomato sauce evenly.",
          "Top with slices of fresh mozzarella and fresh basil leaves.",
          "Drizzle with olive oil and season with salt and pepper.",
          "Bake in the preheated oven for 12-15 minutes or until the crust is golden brown.",
          "Slice and serve hot."
        ],
        prepTime: Measurement(value: 20, unit: .minutes),
        cookTime: Measurement(value: 15, unit: .minutes)
      )

      expectNoDifference(recipe, expectedRecipe)
    }
  }

  @Test("Returns Nil When Random Not Found From Dummy JSON")
  func returnsNilWhenRandomNotFoundFromDummyJSON() async throws {
    let transport = MockHTTPDataTransport { _ in (404, .data(Data())) }
    try await withDependencies {
      $0.withRandomNumberGenerator = WithRandomNumberGenerator(OneGenerator())
      $0[RecipeIDLoaderKey.self] = DummyJSONAPI(transport: transport)
    } operation: {
      @SharedOperation(Recipe.$randomQuery) var recipe
      try await $recipe.load()

      expectNoDifference(recipe, .some(nil))
    }
  }
}

private struct OneGenerator: RandomNumberGenerator {
  func next() -> UInt64 {
    1
  }
}
