import SwiftUI

struct RecipeView: View {
  let recipe: Recipe

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(self.recipe.name).font(.headline)

      VStack(alignment: .leading) {
        Text("Ingredients").font(.headline)
        Text(self.recipe.ingredients.map { "• \($0)" }.joined(separator: "\n"))
      }

      VStack(alignment: .leading) {
        Text("Instructions").font(.headline)
        Text(
          self.recipe.instructions.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        )
      }

      VStack(alignment: .leading) {
        Text("**Prep Time:** \(self.recipe.prepTime.formatted())")
        Text("**Cook Time:** \(self.recipe.cookTime.formatted())")
      }
    }
  }
}
