import Dependencies
import SharingOperation
import SwiftUI

// MARK: - CustomFetchConditionsCaseStudy

struct CustomFetchConditionsCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Custom Run Specifications"
  let description: LocalizedStringKey = """
    The `OperationRunSpecification` protocol allows one to control when a query automatically refetches its \
    data. In fact, this protocol powers library features such as automatically rerunning your \
    operations when your app comes into the foreground, and automatically rerunning your operations \
    when the user's network connection flips from offline to online.

    In this example, we'll create a custom `OperationRunSpecification` conformance called \
    `IsInLowPowerModeRunSpecification` which checks for whether or not the device is in low power mode \
    as the name suggests. When you enable low power mode on your device, the recipe will be \
    refetched, which is achieved by using the `rerunOnChange` on change modifier.
    """

  @State private var client = OperationClient()

  var content: some View {
    withDependencies {
      $0.defaultOperationClient = self.client
    } operation: {
      InnerView()
    }
  }
}

private struct InnerView: View {
  @SharedOperation(Recipe.randomRefetchOnLowPowerModeQuery) private var recipe

  var body: some View {
    Text("Toggle on and off low power mode to refetch the query.")

    BasicQueryStateView(state: self.$recipe.state) { recipe in
      if let recipe {
        RecipeView(recipe: recipe)
      } else {
        Text("Recipe not found.")
      }
    }
  }
}

// MARK: - Queries

extension Recipe {
  fileprivate static let randomRefetchOnLowPowerModeQuery = RandomQuery()
    .disableApplicationActiveRerunning()
    .rerunOnChange(of: IsInLowPowerModeRunSpecification())
}

// MARK: - IsInLowPowerModeRunSpecification

struct IsInLowPowerModeRunSpecification: OperationRunSpecification, Sendable {
  func isSatisfied(in context: OperationContext) -> Bool {
    ProcessInfo.processInfo.isLowPowerModeEnabled
  }

  func subscribe(
    in context: OperationContext,
    onChange observer: @escaping () -> Void
  ) -> OperationSubscription {
    nonisolated(unsafe) let observer = NotificationCenter.default.addObserver(
      forName: .NSProcessInfoPowerStateDidChange,
      object: nil,
      queue: nil,
    ) { _ in
      observer()
    }
    return OperationSubscription {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}

#Preview {
  NavigationStack {
    CustomFetchConditionsCaseStudy()
  }
}
