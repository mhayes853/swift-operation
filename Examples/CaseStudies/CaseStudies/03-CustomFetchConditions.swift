import Dependencies
import SharingOperation
import SwiftUI

// MARK: - CustomFetchConditionsCaseStudy

struct CustomFetchConditionsCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Custom Fetch Conditions"
  let description: LocalizedStringKey = """
    The `FetchCondition` protocol allows one to control when a query automatically refetches its \
    data. In fact, this protocol powers library features such as automatically refetching your \
    queries when your app comes into the foreground, and automatically refetching your queries \
    when the user's network connection flips from offline to online.

    In this example, we'll create a custom `FetchCondition` conformance called \
    `IsInLowPowerModeCondition` which checks for whether or not the device is in low power mode \
    as the name suggests. When you enable low power mode on your device, the recipe will be \
    refetched, which is achieved by using the `refetchOnChange` on change modifier.
    """

  @State private var client = QueryClient()

  var content: some View {
    withDependencies {
      $0.defaultQueryClient = self.client
    } operation: {
      InnerView()
    }
  }
}

private struct InnerView: View {
  @SharedQuery(Recipe.randomRefetchOnLowPowerModeQuery) private var recipe

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
    .disableApplicationActiveRefetching()
    .refetchOnChange(of: IsInLowPowerModeCondition())
}

// MARK: - IsInLowPowerModeCondition

struct IsInLowPowerModeCondition: FetchCondition {
  func isSatisfied(in context: QueryContext) -> Bool {
    ProcessInfo.processInfo.isLowPowerModeEnabled
  }

  func subscribe(
    in context: QueryContext,
    _ observer: @escaping (Bool) -> Void
  ) -> QuerySubscription {
    nonisolated(unsafe) let observer = NotificationCenter.default.addObserver(
      forName: .NSProcessInfoPowerStateDidChange,
      object: nil,
      queue: nil,
    ) { _ in
      observer(ProcessInfo.processInfo.isLowPowerModeEnabled)
    }
    return QuerySubscription {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}

#Preview {
  NavigationStack {
    CustomFetchConditionsCaseStudy()
  }
}
