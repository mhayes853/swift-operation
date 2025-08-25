import Dependencies
import SharingOperation
import SwiftUI

// MARK: - DebouncingCaseStudy

struct DebouncingCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Debouncing"
  let description: LocalizedStringKey = """
    Debouncing is a common tactic for delaying the execution of a query while the user inputs \
    data with high-frequency. Here, we'll use a clock to wait when the user enters search text, \
    and only after they've stopped entering for 0.5 seconds will we fetch the posts with the \
    query string.

    We can do this by reconstructing the query when the 0.5 seconds is up, and assigning that to \
    the `posts` property on `DebouncingModel` using a reusable `DebounceTask` class. This way, we \
    maintain cached results from previous query strings, and can reuse the debouncing logic in \
    other parts of our app.
    """

  @State private var model = DebouncingModel(debounceTime: .seconds(0.5))

  var content: some View {
    HStack {
      TextField("Find in Posts", text: self.$model.text)
      Spacer()
      if self.model.$posts.isLoading {
        ProgressView()
      }
    }

    BasicQueryStateView(state: self.model.$posts.state) { posts in
      if posts.isEmpty {
        ContentUnavailableView(
          "No Posts Matching \"\(self.model.text)\"",
          systemImage: "wand.and.stars"
        )
      } else {
        ForEach(posts) {
          PostView(post: $0, onLikeTapped: nil)
        }
      }
    }
  }
}

// MARK: - DebouncingModel

@MainActor
@Observable
final class DebouncingModel {
  @ObservationIgnored
  @SharedOperation(Post.searchQuery(by: ""), animation: .bouncy) var posts

  var text = "" {
    didSet { self.debounceTask?.schedule() }
  }

  private var debounceTask: DebounceTask?

  init(debounceTime: Duration) {
    @Dependency(\.continuousClock) var clock
    self.debounceTask = DebounceTask(clock: clock, duration: debounceTime) { [weak self] in
      guard let self else { return }
      self.$posts = SharedOperation(Post.searchQuery(by: self.text), animation: .bouncy)
    }
  }
}

extension DebouncingModel {
  func waitForSearchingToBegin() async throws {
    try await self.debounceTask?.waitForCurrent()
  }
}

// MARK: - DebounceTask

@MainActor
final class DebounceTask {
  private let operation: () async throws -> Void
  private var task: Task<Void, any Error>?
  private let clock: any Clock<Duration>
  private let duration: Duration

  init(
    clock: some Clock<Duration>,
    duration: Duration,
    operation: @escaping () async throws -> Void
  ) {
    self.clock = clock
    self.duration = duration
    self.operation = operation
  }

  func schedule() {
    self.task?.cancel()
    self.task = Task {
      try await self.clock.sleep(for: self.duration)
      try await self.operation()
    }
  }

  func waitForCurrent() async throws {
    try await self.task?.value
  }
}

#Preview {
  NavigationStack {
    DebouncingCaseStudy()
  }
}
