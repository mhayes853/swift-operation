# ``OperationCore``
Flexible asynchronous operation and state management for SwiftUI, Linux, WASM, and more.

## Motivation
Dealing with asynchronous work that interacts with external or remote resources is inherently flakey, yet most software needs to do it. Dealing with this flakiness in your application poses a number of challenges including: Tracking loading states, tracking error states, performing retries, exponential backoff, deduplicating operations, pagination, keeping state in sync across different screens, and much more.

Swift Operation is a library that takes care of much of that complexity for you, and additionally allows you to configure that complexity on a per-operation basis.

## Overview
First, we need to define a data type to operate on, and we’ll create an operation to fetch that data. We can create an operation that performs a simple data fetch by making a struct that conforms to the ``QueryRequest`` protocol.
```swift
import Foundation
import Operation

struct Post: Hashable, Identifiable, Sendable, Codable {
  let id: Int
  var userId: Int
  var title: String
  var body: String
}

extension Post {
  static func query(for id: Int) -> some QueryRequest<Self?, any Error> {
    // The modifiers on the query are applied by default, they are
    // only being shown to demonstrate how to configure operations.
    Query(id: id)
      .retry(limit: 3)
      .deduplicated()
      .rerunOnChange(
        of: .connected(to: NWPathMonitorObserver.startingShared())
      )
  }

  struct Query: QueryRequest, Hashable {
    let id: Int

    func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<Post?, any Error>
    ) async throws -> Post? {
      let url = URL(string: "https://dummyjson.com/posts/\(id)")!
      let (data, resp) = try await URLSession.shared.data(from: url)
      if (resp as? HTTPURLResponse)?.statusCode == 404 {
        return nil
      }
      return try JSONDecoder().decode(Post.self, from: data)
    }
  }
}
```

Now, we can track the state of the operation in a SwiftUI view using the `@SharedOperation` property wrapper.
```swift
import SharingOperation
import SwiftUI

struct PostView: View {
  @SharedOperation<Post.Query.State> var post: Post??

  init(id: Int) {
    // By default, this will begin fetching the post.
    self._post = SharedOperation(Post.query(for: id))
  }

  var body: some View {
    Group {
      VStack {
        switch self.$post.status {
        case .result(.success(let post)):
          if let post {
            PostDetailView(post: post)
          } else {
            Text("Post Not Found")
          }
        case .result(.failure(let error)):
          Text("Error: \(error.localizedDescription).")
        case .loading:
          ProgressView()
        default:
          EmptyView()
        }
        Button("Reload") {
          Task { try await self.$post.fetch() }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
```
> Note: The `@SharedOperation` property wrapper and `SharingOperation` target are built on top of the `@Shared` property wrapper from [Sharing](https://github.com/pointfreeco/swift-sharing), the same library that powers the property wrappers found in [SQLiteData](https://github.com/pointfreeco/sqlite-data). This means that you can also use it outside of SwiftUI views such as in `@Observable` models.

### Mutations
Mutations are best suited for operations that create, delete, or update data on remote or external sources they use. A good example of this would be HTTP non-GET requests such as POST, PATCH, PUT, DELETE, etc.

We can create a mutation that creates a post by creating another struct that conforms to the ``MutationRequest`` protcol. A single mutation is designed to work with multiple sets of arguments, which requires us to specify the contents of the post as the mutation’s `Arguments` type.
```swift
extension Post {
  static let createMutation = CreateMutation()

  struct CreateMutation: MutationRequest, Hashable, Sendable {
    struct Arguments: Codable, Sendable {
      let userId: Int
      let title: String
      let body: String
    }

    func mutate(
      isolation: isolated (any Actor)?,
      with arguments: Arguments,
      in context: OperationContext,
      with continuation: OperationContinuation<Post, any Error>
    ) async throws -> Post {
      let url = URL(string: "https://dummyjson.com/posts/add")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.httpBody = try JSONEncoder().encode(arguments)
      request.addValue(
        "application/json",
        forHTTPHeaderField: "Content-Type"
      )
      let (data, _) = try await URLSession.shared.data(for: request)
      return try JSONDecoder().decode(Post.self, from: data)
    }
  }
}
```

Now let’s consume the mutation in a SwiftUI view, which allso utilizes the `@SharedOperation` property wrapper to observe the state of the mutation.
```swift
import SwiftUI
import SharingOperation

struct CreatePostView: View {
  @Environment(\.dismiss) private var dismiss
  let userId: Int
  @State private var title = ""
  @State private var postBody = ""
  @SharedOperation(Post.createMutation) private var create

  var body: some View {
    Form {
      TextField("Title", text: self.$title)
      TextField("Body", text: self.$postBody)

      Button(self.$create.isLoading ? "Creating..." : "Create") {
        Task {
          let args = Post.CreateMutation.Arguments(
            userId: self.userId,
            title: self.title,
            body: self.postBody
          )
          try await self.$create.mutate(with: args)
          self.dismiss()
        }
      }
      .disabled(self.$create.isLoading)

      if let error = self.$create.error {
        Text("Error: \(error.localizedDescription)")
      }
    }
    .navigationTitle("Create Post")
  }
}
```

The key difference between queries and mutations is that a single mutation instance can operate on multiple set or arguments, whereas a single query instance can only operate on the set of members it was constructed with. The `@SharedOperation` property wrapper, as well as the `OperationClient` will utilize this difference as we’ll see later.

### Pagination
Paginated operations can be implemented through the ``PaginatedRequest`` protocol. Similarly to `QueryRequest` and `MutationRequest`, we’ll also create a struct that describes how to fetch a single page of data. In order to know what page needs to be fetched, there’s also a functional requirement that requires us to provide next `PageID` in the list of pages.

Let’s create a paginated operation that provides pages for a feed of posts.
```swift
extension Post {
  struct FeedPage: Codable, Sendable {
    let posts: [Post]
    let total: Int
    let skip: Int
  }
}

extension Post {
  static let feedQuery = FeedQuery()

  struct FeedQuery: PaginatedRequest, Hashable, Sendable {
    private static let limit = 10

    let initialPageId = 0

    func pageId(
      after page: Page<Int, FeedPage>,
      using paging: Paging<Int, FeedPage>,
      in context: OperationContext
    ) -> Int? {
      // Nil means there's no more pages to fetch.
      page.value.skip < page.value.total ? page.id + 1 : nil
    }

    func fetchPage(
      isolation: isolated (any Actor)?,
      using paging: Paging<Int, FeedPage>,
      in context: OperationContext,
      with continuation: OperationContinuation<FeedPage, any Error>
    ) async throws -> FeedPage {
      var url = URL(string: "https://dummyjson.com/posts")!
      url.append(
        queryItems: [
          URLQueryItem(name: "limit", value: "\(Self.limit)"),
          URLQueryItem(
            name: "skip",
            value: "\(paging.pageId * Self.limit)"
          )
        ]
      )
      let (data, _) = try await URLSession.shared.data(from: url)
      return try JSONDecoder().decode(FeedPage.self, from: data)
    }
  }
}
```

Now let’s once again use the `@SharedOperation` property wrapper to created a paginated feed SwiftUI view.
```swift
struct PostsFeedView: View {
  @SharedOperation(Post.feedQuery) private var feed

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 10) {
        ForEach(self.feed) { page in
          ForEach(page.value.posts) { post in
            PostDetailView(post: post)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        if let error = self.$feed.error {
          Text("Error: \(error.localizedDescription)")
        }
        Button(self.$feed.isLoading ? "Loading..." : "Load More") {
          Task { try await self.$feed.fetchNextPage() }
        }
      }
    }
  }
}
```

### Modifiers
Operations can be customized declaratively by using the ``OperationModifier`` protocol. The library uses this protocol to add default behaviors to your operations such as retries and deduplication.

We can conform to the protocol create a modifier that adds artificial delay to an operation. Such a modifier could be useful for SwiftUI previews where you may want to apply such a delay to simulate a long loading state.
```swift
import Operation

extension OperationRequest {
  func delay(
    for duration: OperationDuration
  ) -> ModifiedOperation<Self, DelayModifer<Self>> {
    self.modifier(DelayModifer(duration: duration))
  }
}

struct DelayModifer<
  Operation: OperationRequest
>: OperationModifier, Sendable {
  let duration: OperationDuration

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    try? await context.operationDelayer.delay(for: self.duration)
    return try await operation.run(
      isolation: isolation,
      in: context,
      with: continuation
    )
  }
}

let delayedPostQuery = Post.Query(id: 1).delay(for: .seconds(1))
let delayedCreateMutation = Post.CreateMutation().delay(for: .seconds(1))
let delayedFeedQuery = Post.FeedQuery().delay(for: .seconds(1))
```

The modifier works regardless of the operation type because all operation types inherit from the ``OperationRequest`` protocol, which itself can apply modifiers.

### Multiple Data Updates
You can use the ``OperationContinuation`` instance passed to your operation to yield multiple data updates before returning. For example, you may want to temporarily yield cached data from disk while fetching the real live data from your server.
```swift
extension Post {
  struct CachedQuery: QueryRequest, Hashable {
    let id: Int

    func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<Post?, any Error>
    ) async throws -> Post? {
      async let post = self.fetchPost(for: self.id)
      if let cached = try PostCache.shared.post(for: self.id) {
        continuation.yield(cached)
      }
      return try await post
    }

    // ...
  }
}
```
> Note: To learn more about multiple data updates, checkout <doc:MultistageOperations>. Additionally, you can also find usage examples such as [file downloads](https://github.com/mhayes853/swift-operation/blob/main/Examples/CaseStudies/CaseStudies/02-Downloads.swift) and [FoundationModels streaming](https://github.com/mhayes853/swift-operation/blob/main/Examples/CanIClimb/CanIClimbKit/Sources/CanIClimbKit/MountainsCore/ClimbReadiness/Mountain%2BClimbReadinessGeneration.swift) in the demos.

### Sharing State
Using different instances of the `@SharedOperation` property wrapper with the same operation will efficiently share the state of the operation across both usages. In the following example, both `ParentView` and `ChildView` will observe state from the fetch of the post, that is the post will only be fetched a single time despite 2 instances of the property wrapper being in-memory.
```swift
import SharingOperation
import SwiftUI

// ParentView and ChildView observe the same post operation.
// Therefore the post is only fetched a single time.

struct ParentView: View {
  @SharedOperation(Post.query(for: 10)) private var post

  var body: some View {
    ChildView()
  }
}

struct ChildView: View {
  @SharedOperation(Post.query(for: 10)) private var post

  var body: some View {
    // ...
  }
}
```

The reason this works is because `@SharedOperation` uses the same ``OperationStore`` instance under the hood for both instances in `ParentView` and `ChildView`.

`OperationStore` is the runtime of an operation, and invokes your operation whilst managing its state directly. It has a ``OperationStore/subscribe(with:)-(OperationEventHandler<State>)`` method that `@SharedOperation` wraps such that you can observe the state in SwiftUI views and more.

`@SharedOperation` is able to use the same store instance under the hood due to the ``OperationClient`` class. `OperationClient` is a class that manages all `OperationStore` instances in your application. You can access the client through the `@Dependency(\.defaultOperationClient)` property wrapper from [swift-dependencies](https://github.com/pointfreeco/swift-dependencies/tree/main).
```swift
import SharingOperation

struct SendFriendRequestMutation: MutationRequest, Hashable {
  // ...

  func mutate(
    isolation: isolated (any Actor)?,
    with arguments: Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<Void, any Error>
  ) async throws {
    @Dependency(\.defaultOperationClient) var client
    try await sendFriendRequest(userId: arguments.userId)

    // Friend request succeeded, now optimistically update the state
    // of all friends list queries in the app.
    let stores = client.stores(
      matching: ["user-friends"],
      of: User.FriendsQuery.State.self
    )
    for store in stores {
      store.withExclusiveAccess { store in
        store.currentValue = store.currentValue.updateRelationship(
          for: arguments.userId,
          to: .friendRequestSent
        )
      }
    }
  }
}
```
> Note: To learn more about advanced state management practices including pattern matching using the ``OperationPath`` type, similar to [Tanstack Query’s query key](https://tanstack.com/query/latest/docs/framework/react/guides/query-keys) pattern matching, checkout <doc:PatternMatchingAndStateManagement>.

## Traits
The library ships with a handful of package traits, which allow you to conditionally compile dependencies and features of the library. You can learn more about package traits from reading the official evolution [proposal](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md).
- `SwiftOperationLogging` - Adds swift-log support to the library, including a `Logger` context property and the `logDuration` modifier.
- `SwiftOperationWebBrowser` - Integrates web browser APIs with the library using JavaScriptKit. (Only enable for WASM Browser Applications).
- `SwiftOperationNavigation` - Integrates SwiftNavigation's `UITransaction` with `@SharedOperation`.
- `SwiftOperationUIKitNavigation` - Integrates UIKitNavigation's `UIKitAnimation` with `@SharedOperation`.
- `SwiftOperationAppKitNavigation` - Integrates AppKitNavigation's `AppKitAnimation` with `@SharedOperation`.

## Topics

### Operations
- ``OperationRequest``
- ``OperationContext``
- ``OperationContinuation``
- ``QueryRequest``
- ``MutationRequest``
- ``PaginatedRequest``
- <doc:UtilizingOperationContext>
- <doc:MultistageOperations>
- <doc:DependentOperations>
- <doc:NetworkLayer>
- <doc:Testing>
- <doc:CustomOperationTypes>

### Operation State
- ``StatefulOperationRequest``
- ``OperationState``
- ``OperationStatus``
- ``QueryState``
- ``MutationState``
- ``PaginatedState``
- ``OpaqueOperationState``
- ``OperationStore/resetState(using:)``
- ``OperationStateResetEffect``

### Operation Client
- ``OperationClient``
- ``OperationClient/StoreCache``
- ``OperationClient/StoreCreator``

### Operation Store
- ``OperationStore``
- ``OperationClient/store(for:initialState:)->OperationStore<Operation.State>``
- ``OpaqueOperationStore``

### Operation Path
- ``OperationPath``
- ``OperationPathable``
- ``OperationPathableCollection``
- ``OperationClient/stores(matching:of:)``
- ``OperationClient/withStores(matching:of:perform:)``
- <doc:PatternMatchingAndStateManagement>

### Stale When Revalidate
- ``StatefulOperationRequest/staleWhen(predicate:)``
- ``StatefulOperationRequest/staleWhenNoValue()``
- ``StatefulOperationRequest/stale(after:)``
- ``StatefulOperationRequest/staleWhen(satisfying:)``
- ``OperationStore/isStale``

### Default Values
- ``DefaultOperationState``
- ``DefaultableOperationState``
- ``DefaultStateOperation``
- ``StatefulOperationRequest/defaultValue(_:)``
- <doc:OperationDefaults>

### Event Handling
- ``OperationEventHandler``
- ``OpaqueOperationEventHandler``
- ``OperationResultUpdateReason``
- ``OperationStore/subscribe(with:)-(OperationEventHandler<State>)``
- ``StatefulOperationRequest/handleEvents(with:)``

### Modifiers
- ``OperationModifier``
- ``ModifiedOperation``
- ``OperationRequest/backoff(_:)``
- ``OperationRequest/clock(_:)``
- ``OperationRequest/retry(limit:)``
- ``OperationRequest/taskConfiguration(_:)-((OperationTaskConfiguration)->Void)``
- ``OperationRequest/deduplicated()``
- ``OperationRequest/modifier(_:)``

### Queries
- ``QueryRequest``
- ``QueryState``
- ``QueryEventHandler``
- ``OperationStore/fetch(using:handler:)``

### Mutations
- ``MutationRequest``
- ``MutationState``
- ``MutationEventHandler``
- ``MutationOperationValue``
- ``MutationState/HistoryEntry``
- ``MutationRequest/maxHistory(length:)``
- ``OperationStore/mutate(with:using:handler:)``
- ``OperationStore/retryLatest(using:handler:)``

### Pagination
- ``PaginatedRequest``
- ``PaginatedState``
- ``PaginatedEventHandler``
- ``Pages``
- ``Paging``
- ``Page``
- ``PagingRequest``
- ``PagesFor``
- ``PaginatedOperationValue``
- ``OperationStore/fetchNextPage(using:handler:)``
- ``OperationStore/fetchPreviousPage(using:handler:)``
- ``OperationStore/refetchAllPages(using:handler:)``

### Controllers
- ``OperationController``
- ``ControlledOperation``
- ``OperationControls``
- ``StatefulOperationRequest/controlled(by:)``

### Run Specifications
- ``OperationRunSpecification``
- ``AlwaysRunSpecification``
- ``AsyncSequenceRunSpecification``
- ``PublisherRunSpecification``
- ``AnySendableRunSpecification``
- ``StatefulOperationRequest/enableAutomaticRunning(onlyWhen:)``
- ``StatefulOperationRequest/rerunOnChange(of:)``
- <doc:UtilizingRunSpecifications>

#### Boolean Operators
- ``&&(_:_:)``
- ``||(_:_:)``
- ``BinaryOperatorRunSpecification``
- ``!(_:)``
- ``NotRunSpecification``

### Subscriptions
- ``OperationSubscription``

### Network Connection Observing
- ``NetworkObserver``
- ``NetworkConnectionStatus``
- ``NetworkConnectionRunSpecification``
- ``AnySendableNetworkObserver``
- ``NWPathMonitorObserver``
- ``MockNetworkObserver``
- ``OperationRequest/satisfiedConnectionStatus(_:)``
- ``OperationRequest/completelyOffline(_:)``

### Application Activity Observing
- ``ApplicationActivityObserver``
- ``ApplicationIsActiveRunSpecification``
- ``UIApplicationActivityObserver``
- ``NSApplicationActivityObserver``
- ``WKExtensionActivityObserver``
- ``WKApplicationActivityObserver``
- ``OperationRequest/disableApplicationActiveRerunning(_:)``

### Memory Pressure Observing
- ``MemoryPressureSource``
- ``MemoryPressure``
- ``DispatchMemoryPressureSource``
- ``OperationRequest/evictWhen(pressure:)``

### Controlling Time
- ``OperationClock``
- ``SystemTimeClock``
- ``TimeFreezeClock``
- ``CustomOperationClock``
- ``OperationClock/frozen()``

### Backoff
- ``OperationBackoffFunction``
- ``OperationBackoffFunction/exponential(_:)``
- ``OperationRequest/backoff(_:)``
- ``OperationDelayer``
- ``TaskSleepDelayer``
- ``NoDelayer``
- ``AnySendableDelayer``
- ``ClockDelayer``
- ``OperationRequest/delayer(_:)``
- ``OperationDuration``

### Tasks
- ``OperationTask``
- ``OperationTask/runIfNeeded()``
- ``OperationTaskIdentifier``
- ``OperationTaskConfiguration``
- ``OperationTaskInfo``
- ``OperationRequest/taskConfiguration(_:)-((OperationTaskConfiguration)->Void)``
- ``OperationStore/runTask(using:)``
- ``QueryState/activeTasks``

### Async Sequences
- ``OperationStore/AsyncStates``
- ``OperationStore/states``

### Combine
- ``OperationStore/Publisher``
- ``OperationStore/publisher``
- ``OperationSubscription/Combine``
