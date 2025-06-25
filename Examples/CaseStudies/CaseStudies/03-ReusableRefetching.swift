import SwiftUI
import SharingQuery
import Dependencies

// MARK: - ReusableRefetchingCaseStudy

struct ReusableRefetchingCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Reusable Refetching"
  let description: LocalizedStringKey = """
    You may want to refetch queries when some event occurs in your application (eg. a user logging \
    out), but do so on many distinct queries. You can reuse this refetching logic using the \
    `QueryController` protocol.
    
    Here, we'll use `NotificationCenter` to observe when you take a screenshot on your device. \
    Every time you take a screenshot, the queries on screen will refetch themselves.
    """
  
  // NB: Use a separate query client instance to avoid QueryPath clashes with other case studies.
  @State private var client = QueryClient()
  
  var content: some View {
    withDependencies {
      $0.defaultQueryClient = self.client
    } operation: {
      InnerView()
    }
  }
}

// MARK: - InnerView

private struct InnerView: View {
  @SharedQuery(Quote.randomScreenshotQuery) private var quote
  @SharedQuery(Recipe.randomScreenshotQuery) private var recipe
  
  var body: some View {
    Text("Take a screenshot to refetch the queries!").font(.title3.bold())
    BasicQueryStateView(state: self.$quote.state) {
      QuoteView(quote: $0)
    }
    BasicQueryStateView(state: self.$recipe.state) { r in
      if let r {
        RecipeView(recipe: r)
      } else {
        Text("Recipe not found.")
      }
    }
  }
}

// MARK: - Queries

extension Recipe {
  static let randomScreenshotQuery = RandomQuery()
    .refetchOnPost(of: UIApplication.userDidTakeScreenshotNotification)
}

extension Quote {
  static let randomScreenshotQuery = RandomQuery()
    .refetchOnPost(of: UIApplication.userDidTakeScreenshotNotification)
}

// MARK: - Refetch On Notification

extension QueryRequest {
  func refetchOnPost(
    of name: Notification.Name,
    center: NotificationCenter = .default
  ) -> ModifiedQuery<
    Self,
    _QueryControllerModifier<Self, RefetchOnNotificationController<State>>
  > {
    self.controlled(by: RefetchOnNotificationController(notification: name, center: center))
  }
}

struct RefetchOnNotificationController<State: QueryStateProtocol>: QueryController {
  let notification: Notification.Name
  let center: NotificationCenter
  
  func control(with controls: QueryControls<State>) -> QuerySubscription {
    nonisolated(unsafe) let observer = self.center.addObserver(
      forName: self.notification,
      object: nil,
      queue: nil
    ) { _ in
      let task = controls.yieldRefetchTask()
      Task { try await task?.runIfNeeded() }
    }
    return QuerySubscription { self.center.removeObserver(observer) }
  }
}

#Preview {
  NavigationStack {
    ReusableRefetchingCaseStudy()
  }
}
