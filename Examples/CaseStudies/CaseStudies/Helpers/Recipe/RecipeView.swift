import SwiftUI

struct RecipeView: View {
  let recipe: Recipe
  
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(self.recipe.name).font(.headline)
      
      VStack(alignment: .leading) {
        Text("Ingredients").font(.headline)
        ForEach(self.recipe.ingredients, id: \.self) {
          Text($0)
        }
      }
      
      VStack(alignment: .leading) {
        Text("Instructions").font(.headline)
        ForEach(self.recipe.instructions, id: \.self) {
          Text($0)
        }
      }
      
      VStack(alignment: .leading) {
        Text("**Prep Time:** \(self.recipe.prepTime.formatted())")
        Text("**Cook Time:** \(self.recipe.cookTime.formatted())")
      }
    }
  }
}
