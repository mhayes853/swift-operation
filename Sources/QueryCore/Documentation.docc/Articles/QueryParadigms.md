# Queries, Infinite Queries, and Mutations

Learn about the different paradigms of fetching and managing data with the library, and how you can even create your own paradigms using the tools in the library.

## Overview

The library provides 3 query paradigms that are applicable to different situations:

1. **Queries**: The most basic paradigm that supports fetching any kind of data.
2. **Infinite Queries**: A paradigm for fetching paginated data that can be put into an infinite scrollable list piece by piece.
3. **Mutations**: A paradigm for updating data asynchronously, such as performing a POST request to an API.

Infinite queries and mutations are both built directly on top of ordinary queries, and so all modifiers and functionallity that works with traditional queries will also work with those 2 paradigms.

Let's dive into the basics of each paradigm, and even show an example how you can create your own paradigm.

## Queries

Queries are the most basic fetching paradigm the library offers. Just creating a conformance to the ``QueryRequest`` protocol already unlocks a lot of power, such as retries and more.

```swift
struct PlayerQuery: QueryRequest, Hashable {
  let id: Int

  func fetch(
    in context: QueryContext,
    using continuation: QueryContinuation<Player>
  ) async throws -> Player {
    // Fetch player with id...
  }
}

let query = PlayerQuery(id: 200)
  .retry(limit: 3)
  .deduplicated()
  .stale(after: fiveMinutes)
  .refetchOnChange(of: .loggedInUser)
```

All that you must do is fetch your data inside `PlayerQuery`, and the library gives you powerful tools that work directly on top of that logic. Though the query paradigm is by far the most basic, it serves as the baseline for implementing other paradigms such as infinite queries and mutations.

## Infinite Queries

If you have a paginated or infinitely scrollable list in your app, infinite queries are the paradigm for you. Conforming to the ``InfiniteQueryRequest`` protocol is a little bit more work than `QueryRequest`, but that is only because you need to provide a notion of how pages are to be fetched. Despite this, know that `InfiniteQueryRequest` inherits from `QueryRequest`, so modifiers that work on traditional queries will also work on infinite queries.

```swift
struct PlayersPage: Sendable, Codable {
  let players: [Player]
  let nextPageKey: String?
  let previousPageKey: String?

  var isLastPage: Bool { nextPageKey == nil }
  var isFirstPage: Bool { previousPageKey == nil }
}

struct PlayersQuery: InfiniteQueryRequest, Hashable {
  typealias PageID = String
  typealias PageValue = PlayersPage

  let listId: Int

  // Requirement 1 (Provide the initial page index that can be any Hashable
  // and Sendable type.)
  let initialPageId = "initial"

  // Requirement 2 (Provide a way to determine the next page id from the
  // previous page, which can be the next page token that your API
  // returns for the previous page.)
  func pageId(
    after page: InfiniteQueryPage<String, PlayersPage>,
    using paging: InfiniteQueryPaging<String, PlayersPage>,
    in context: QueryContext
  ) -> String? {
    page.value.isLastPage ? nil : page.value.nextPageKey
  }

  // [OPTIONAL] Requirement 3 (Provide a way to determine the previous page id
  // from the first page, which can be the previous page token that your API
  // returns for the previous page.)
  func pageId(
    before page: InfiniteQueryPage<String, PlayersPage>,
    using paging: InfiniteQueryPaging<String, PlayersPage>,
    in context: QueryContext
  ) -> String? {
    page.value.isFirstPage ? nil : page.value.previousPageKey
  }

  // Requirement 4 (Fetch the data for a page.)
  func fetchPage(
    using paging: InfiniteQueryPaging<String, PlayersPage>,
    in context: QueryContext,
    with continuation: QueryContinuation<PlayersPage>
  ) async throws -> PlayersPage {
    // Fetch the list of players for the page...
  }
}
```

With this now, you're nearly up and running. You control how pages are fetched through a ``QueryStore`` instance, when the state for the store is ``InfiniteQueryState``, the store provides a few additional methods for fetching parts of the query.

```swift
let store = client.store(for: PlayersQuery(listId: 20))

// Fetching all pages.
try await store.fetch() // Fetches initial page if no pages have been fetched yet.
try await store.fetchAllPages()

// Fetching next page.
// Fetches initial page if no pages have been fetched yet.
try await store.fetchNextPage()

// Fetching previous page.
// Fetches initial page if no pages have been fetched yet.
try await store.fetchPreviousPage()
```

> Note: It should be noted that if you're using SwiftUI, then you can access these methods through the projected value of ``SwiftUICore/State/Query``.
> ```swift
> import SwiftUI
> import Query
>
> struct PlayersView: View {
>   @State.Query(PlayersQuery(listId: 20)) private var state
>
>   var body: some View {
>     // ...
>   }
>
>   private func fetch() async throws {
>     // Fetching all pages.
>     try await $state.fetch() // Fetches initial page if no pages have been fetched yet.
>     try await $state.fetchAllPages()
>
>     // Fetching next page.
>     // Fetches initial page if no pages have been fetched yet.
>     try await $state.fetchNextPage()
>
>     // Fetching previous page.
>     // Fetches initial page if no pages have been fetched yet.
>     try await $state.fetchPreviousPage()
>   }
> }
> ```

The state value of infinite query is an ``InfiniteQueryPages`` type, which is just an [`IdentifiedArray`](https://github.com/pointfreeco/swift-identified-collections) under the hood. Each element of the array is of type ``InfiniteQueryPage``, which contains a field for the page id along with the value of the page.

```swift
let store = client.store(for: PlayersQuery(listId: 20))

for page in store.currentValue {
  print("Page Id", page.id)
  print("Players", page.value.players)
}
```

### Infinite Query Concurrency

The previous and next page of an infinite query can be fetched at the same time. However, requests to fetch all pages will have to wait for all next and previous page requests to finish. Likewise, requests to fetch the next or previous pages must wait for requests to fetch all pages to finish. Furthermore, when the intial page is being fetched, requests for all, the next, and previous pages must wait for the initial page to be fetched. The initial page is only fetched when there are no pages present in the state.

```swift
let store = client.store(for: PlayersQuery(listId: 20))

// Can fetch at the same time, but will first wait for any active
// "all pages" or "initial page" requests to finish.
try await store.fetchNextPage()
try await store.fetchPreviousPage()

// Will wait for all "next page", "previous page", or "initial page"
// requests to finish before fetching.
try await store.fetchAllPages()
```

## Mutations

Mutations are a query paradigm for performing updates on your data's remote source. A clear example of this would be a POST request to an API that creates a new record of something. Conforming to the ``MutationRequest`` protocol is quite straightforward, and just like `InfiniteQueryRequest` the protocol also inherits from `QueryRequest` enabling modifiers that work for traditional queries to also work for mutations.

```swift
struct CreatePlayerMutation: MutationRequest, Hashable {
  struct Arguments: Sendable {
    let name: String
    let number: Int
  }

  func mutate(
    with arguments: Arguments,
    in context: QueryContext,
    with continuation: QueryContinuation<Player>
  ) async throws -> Player {
    // POST to the API to create a player...
  }
}
```

You'll notice that unlike `QueryRequest` and `InfiniteQueryRequest` conformances, providing arguments is represented through the `Arguments` associated type rather than member variables the mutation itself. Additionally, just like `InfiniteQueryState`, the `QueryStore` provides special data fetching methods when its state is ``MutationState``.

```swift
let store = client.store(for: CreatePlayerMutation())

// Retry latest argument set.
try await store.fetch()
try await store.retryLatest()

// Mutate with arguments.
try await store.mutate(
  with: CreatePlayerMutation.Arguments(name: "Blob", number: 42)
)
```

> Note: It should be noted that if you're using SwiftUI, then you can access these methods through the projected value of `@State.Query`.
> ```swift
> import SwiftUI
> import Query
>
> struct CreatePlayerView: View {
>   @State.Query(CreatePlayerMutation()) private var state
>   @State private var name = ""
>   @State private var number = 0
>
>   var body: some View {
>     // ...
>   }
>
>   private func createPlayer() async throws {
>     try await $state.mutate(
>       with: CreatePlayerMutation.Arguments(name: name, number: number)
>     )
>   }
> }
> ```

### Mutation History

Another superpower of utilizing an associated type for arguments on `MutationRequest` is for the ability of `MutationState` to hold onto an entire history of mutate attempts and their results. This makes it easy to write logic based on the number of subsmission attempts and previously submitted data of a form for instance.

```swift
import SwiftUI
import Query

struct CreatePlayerView: View {
  @State.Query(CreatePlayerMutation()) private var state
  @State private var name = ""
  @State private var number = 0

  // We know many previous attempts to create a player with this name failed,
  // so we can mark the name as problematic.

  private var isInvalidName: Bool {
    state.history.count { $0.arguments.name == name && $0.status.isFailure } >= 3
  }

  var body: some View {
    Form {
      // ...

      if isInvalidName {
        Text("\(name) is an invalid name.")
      }

      Button("Submit") {
        Task { try await createPlayer() }
      }
      .disabled(isInvalidName)
    }
  }

  // ...
}
```

In the above example, we can see that if we've tried to unsuccessfully submit a player with a certain name more than 3 times, we no longer allow the player name to be submitted. This is possible because the mutation keeps track of the entire history of successful and unsuccessful attempts.

## Building Your Own Data Fetching Paradigm

The library provides 3 very common data fetching paradigms, but you can also build your own if needed. This topic is considerably more advanced than other topics in the library, but in general this should be quite rare. Regardless, it does show how the library is quite flexible, and with a little work can be adapted to your needs.

For this example, let's try to build a query paradigm for "recursive queries". In other words, a paradigm that works well for fetching recursive data like comment threads on a social media app. In such a case, the query data is tree-like, and we'll need the ability to fetch subtrees of each branch. Inherently, this means that we'll need to be able to identify a node of the tree in our query.

Therefore, our first move will be to create a protocol that inherits from `QueryRequest`, as doing so will ensure that base functionallity on typical queries will also work on our new paradigm.

```swift
protocol RecursiveQueryRequest: QueryRequest {
  associatedtype NodeID: Sendable
}
```

Next, we'll need to ensure that the protocol works with tree like data. Which can be achieved with another protocol that forces the data to be tree like.

```swift
protocol RecursiveValue<NodeID>: Sendable {
  associatedtype NodeID: Sendable & Equatable

  var nodeId: NodeID { get }
  var children: [Self] { get set }
}

extension RecursiveValue {
  // Convenience subscript to get and set any node in the tree.
  subscript(id nodeId: NodeID) -> Self? {
    get { /* ... */ }
    set { /* ... */ }
  }
}
```

Then we can update `RecursiveQueryRequest` to ensure that the `Value` generic conforms to `RecursiveValue`.

```diff
- protocol RecursiveQueryRequest: QueryRequest {
+ protocol RecursiveQueryRequest: QueryRequest
+ where Value: RecursiveValue<NodeID> {
  associatedtype NodeID: Sendable
}
```

Given that we'll be fetching branches of the tree, we'll need to make a fetch requirement for fetching a particular subtree on `RecursiveQueryRequest`.

```diff
protocol RecursiveQueryRequest: QueryRequest
where Value: RecursiveValue<NodeID> {
  associatedtype NodeID: Sendable

+  func fetchTree(
+    for id: NodeID,
+    in context: QueryContext,
+    with continuation: QueryContinuation<Value>
+  ) async throws -> Value
}
```

That requirement allows us to fetch a tree when given a specific `NodeID`. However, how do we determine what the root id is? It turns out that we'll also need a requirement for that too similar to how `InfiniteQueryRequest` also has an `initialPageId` requirement.

```diff
protocol RecursiveQueryRequest: QueryRequest
where Value: RecursiveValue<NodeID> {
  associatedtype NodeID: Sendable

+ var rootNodeId: NodeID { get }

  func fetchTree(
    for id: NodeID,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value
}
```

At this point, we've defined how recursive requests work on the data fetching level. Yet we haven't described how managing the state for the query works. All other query paradigms come with a value type that conforms to the ``QueryStateProtocol`` such as `InfiniteQueryState`. Similarly, we'll need a state type that describes how the state is managed for our recursive query.

```swift
struct RecursiveQueryState<Value: RecursiveValue>: QueryStateProtocol {
  typealias StateValue = Value
  typealias QueryValue = Value
  typealias StatusValue = Value

  private(set) var currentValue: Value
  let initialValue: Value
  private(set) var valueUpdateCount = 0
  private(set) var valueLastUpdatedAt: Date?
  private(set) var error: (any Error)?
  private(set) var errorUpdateCount = 0
  private(set) var errorLastUpdatedAt: Date?
  private(set) var activeTasks = IdentifiedArrayOf<QueryTask<Value>>()

  init(initialValue: Value) {
    self.currentValue = initialValue
    self.initialValue = initialValue
  }

  // We'll come back to the function requirements later...
}
```

This means that we'll need to update the `RecursiveQueryRequest` protocol by constraining the type of state we can use on the protocol.

```diff
protocol RecursiveQueryRequest: QueryRequest
- where Value: RecursiveValue<NodeID> {
+ where Value: RecursiveValue<NodeID>, State == RecursiveQueryState<Value> {
  associatedtype NodeID: Sendable

  var rootNodeId: NodeID { get }

  func fetchTree(
    for id: NodeID,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value
}
```

Now with all of our basic types in place, we'll almost certainly want to provide helper methods on `QueryStore` that allow us to fetch a specific subtree. We can do this by extending the store with a constraint that ensures that the `State` generic is some kind of `RecursiveQueryState` instance.

```swift
// 🔴 This is a compiler error.
extension QueryStore where State == RecursiveQueryState {
  // More to come...
}
```

However, we'll see that we need to specify generics for `RecursiveQueryState` in the extension. However, we want this extension to work for any kind of `RecursiveQueryState`, and we don't really care about any concrete generics. We can solve this by making an intermediate protocol, and conforming `RecursiveQueryState` to it. Then, we should be able to extend the `QueryStore` in a way that constrains the `State` generic to `RecursiveQueryState`.

```swift
protocol _RecursiveQueryStateProtocol: QueryStateProtocol
where
  StateValue: RecursiveValue<NodeID>,
  QueryValue: RecursiveValue<NodeID>,
  StatusValue: RecursiveValue<NodeID>
{
  associatedtype NodeID: Sendable
}

extension RecursiveQueryState: _RecursiveQueryStateProtocol {
  typealias NodeID = Value.NodeID
}

extension QueryStore where State: _RecursiveQueryStateProtocol {
  // More to come...
}
```

Now that allows us to define a method to fetch a subtree of the query state on `QueryStore`.

```swift
extension QueryStore where State: _RecursiveQueryStateProtocol {
  func fetchTree(
    for id: State.NodeID,
    using configuration: QueryTaskConfiguration? = nil
  ) async throws -> State.QueryValue {
    // ...
  }
}
```

`QueryStore` by default only has a `fetch` method for fetching data that generally is designed to fetch the entirety of the data at once. However, in our case we're merely trying to fetch a part of the overall data by focusing on a subtree. To get around this, we'll need to rely on the ``QueryContext`` present in the ``QueryTaskConfiguration`` parameter in `fetchTree`. If no task configuration is provided, we can simply create one with our store's context.

```swift
extension QueryStore where State: _RecursiveQueryStateProtocol {
  func fetchTree(
    for id: State.NodeID,
    using configuration: QueryTaskConfiguration? = nil
  ) async throws -> State.QueryValue {
    var configuration = configuration ?? QueryTaskConfiguration(context: context)
    // More to come...
  }
}
```

In order to pass the node id to the query, we'll need to create a custom `QueryContext` property. If you're familiar with how to create custom `EnvironmentValues` properties in SwiftUI, it's a very similar process for the `QueryContext`.

```swift
struct RecursiveQueryContextValues: Sendable {
  var nodeId: (any Sendable)?
}

extension QueryContext {
  var recursiveValues: RecursiveQueryContextValues {
    get { self[RecursiveQueryContextValuesKey.self] }
    set { self[RecursiveQueryContextValuesKey.self] = newValue }
  }

  private enum RecursiveQueryContextValuesKey: Key {
    static var defaultValue: RecursiveQueryContextValues {
      RecursiveQueryContextValues()
    }
  }
}
```

Now we can use our new context property to pass our node id through to the query.

```swift
extension QueryStore where State: _RecursiveQueryStateProtocol {
  func fetchTree(
    for id: State.NodeID,
    using configuration: QueryTaskConfiguration? = nil
  ) async throws -> State.QueryValue {
    var configuration = configuration ?? QueryTaskConfiguration(context: context)
    configuration.context.recursiveValues.nodeId = id
    return try await fetch(using: configuration)
  }
}
```

The first thing that happens when `fetch` is called on a `QueryStore` is that the store will try to schedule a `QueryTask` on the current `State`. So we'll implement `scheduleFetchTask` on `RecursiveQueryState`.

```swift
struct RecursiveQueryState<Value: RecursiveValue>: QueryStateProtocol {
  // ...

  var isLoading: Bool {
    !self.activeTasks.isEmpty
  }

  mutating func scheduleFetchTask(_ task: inout QueryTask<Value>) {
    activeTasks.append(task)
  }

  // More to come...
}
```

> Note: In a real implementation, we may want to see if we are also fetching subtrees for the parent nodes and wait for those tasks to finish first before fetching the subtree. For that we can use the ``QueryTask/schedule(after:)-(QueryTask<V>)`` API.

As we can see here, we just need to append the task to our list of active tasks on the state, and we can even compute `isLoading` by checking if there are any active tasks on the state.

After scheduling the task on the state, the `QueryStore` will then try to invoke `fetch` on the underlying `RecursiveQueryRequest` protocol. However, we have no default implementation of `fetch` on the protocol, so conforming types will have to implement it manually. Instead, let's fill in a default implementation that calls down to `fetchTree` such that we don't burden recursive requests with having to implement it manually.

```swift
extension RecursiveQueryRequest {
  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    if let nodeId = context.recursiveValues.nodeId as? NodeID {
      return try await fetchTree(for: nodeId, in: context, with: continuation)
    } else {
      // If we have no node id in the context (eg. We called `fetch` directly
      // the `QueryStore` instead of `fetchTree`), we'll assume we're refetching
      // from the root.
      return try await fetchTree(for: rootNodeId, in: context, with: continuation)
    }
  }
}
```

As the query runs, results will be yielded from the query either through ``QueryContinuation`` or through returning the final value. When this happens, the `QueryStore` will invoke a method on the `State` signifying that a result was yielded from the query. Therefore, we'll implement the `update` requirement for `RecursiveQueryState` that handles a result paired with the associated ``QueryTask``.

```swift
struct RecursiveQueryState<Value: RecursiveValue>: QueryStateProtocol {
  // ...

  mutating func update(
    with result: Result<QueryValue, any Error>,
    for task: QueryTask<QueryValue>
  ) {
    switch result {
    case let .success(value):
      self.currentValue[id: value.nodeId] = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = task.configuration.context.queryClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = task.configuration.context.queryClock.now()
    }
  }

  // More to come...
}
```

> Note: We'll use the query clock in the context here to compute the dates for `valueLastUpdatedAt` and `errorLastUpdatedAt`. This allows the clock to be overriden in testing such that a deterministic date is provided.

Once the query itself stops running, the `QueryStore` will indicate to the state that the task has been finished. This is implemented through another requirement on `RecursiveQueryState`. All we have to do here is remove the finished task from the list of active tasks.

```swift
struct RecursiveQueryState<Value: RecursiveValue>: QueryStateProtocol {
  // ...

  mutating func finishFetchTask(_ task: QueryTask<QueryValue>) {
    activeTasks.remove(id: task.id)
  }

  // More to come...
}
```

At this point the basics of our recursive query paradigm are implemented. Yet there are still 2 more requirements that we need to implement on `RecursiveQueryState`.

### Setting State Manually

`QueryStateProtocol` has 2 `update` requirements. The first is when the in progress query yields a value when fetching, and this is associated with a `QueryTask`. However, the `QueryStore` also allows us to set the state value of the query directly, which is useful for optimistic UI updates and much more. For this, `QueryStateProtocol` has another update requirement, this time taking a result to the `StateValue` with a `QueryContext`. Implementing this is almost identical to the other `update` requirement on `RecursiveQueryState`.

```swift
struct RecursiveQueryState<Value: RecursiveValue>: QueryStateProtocol {
  // ...

  mutating func update(
    with result: Result<StateValue, any Error>,
    using context: QueryContext
  ) {
    switch result {
    case let .success(value):
      self.currentValue[id: value.nodeId] = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.queryClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.queryClock.now()
    }
  }

  // More to come...
}
```

In fact, we can even utilize this implementation in the other `update` requirement since `StateValue` and `QueryValue` are equivalent in `RecursiveQueryState`.

```diff
struct RecursiveQueryState<Value: RecursiveValue>: QueryStateProtocol {
  // ...

  mutating func update(
    with result: Result<QueryValue, any Error>,
    for task: QueryTask<QueryValue>
  ) {
-  switch result {
-   case let .success(value):
-     self.currentValue[id: value.nodeId] = value
-     self.valueUpdateCount += 1
-     self.valueLastUpdatedAt = context.queryClock.now()
-     self.error = nil
-   case let .failure(error):
-     self.error = error
-     self.errorUpdateCount += 1
-     self.errorLastUpdatedAt = context.queryClock.now()
-   }
+   update(with: result, using: task.configuration.context)
  }

  // More to come...
}
```

### Resetting State

It's also possible to reset the entire `State` on a `QueryStore` via ``QueryStore/reset(using:)``. When doing this, the store calls out to the `State` to reset itself, which is represented via a `reset` requirement on `QueryStateProtocol`. When implementing this protocol, you generally will cancel all active tasks on the state, and then reset all of the values.

```swift
struct RecursiveQueryState<Value: RecursiveValue>: QueryStateProtocol {
  // ...

  mutating func reset(using context: QueryContext) {
    for task in activeTasks {
      task.cancel()
    }
    self = Self(initialValue: initialValue)
  }
}
```

All of those cancelled tasks will throw a `CancellationError`, however those errors will not be reflected in your reset state as `QueryStore` is smart enough to know that resetting means completely setting a clean slate.

### Concluding Our Custom Fetching Paradigm

At this point, we've implemented a basic custom paradigm! Here's all the code that we wrote below.

```swift
protocol RecursiveValue<NodeID>: Sendable {
  associatedtype NodeID: Sendable & Equatable

  var nodeId: NodeID { get }
  var children: [Self] { get set }
}

extension RecursiveValue {
  subscript(id nodeId: NodeID) -> Self? {
    get { /* Recursive traversal... */ }
    set { /* Recursive traversal... */ }
  }
}

protocol RecursiveQueryRequest: QueryRequest
where Value: RecursiveValue<NodeID>, State == RecursiveQueryState<Value> {
  associatedtype NodeID: Sendable

  var rootNodeId: NodeID { get }

  func fetchTree(
    for id: NodeID,
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value
}

extension RecursiveQueryRequest {
  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value {
    if let nodeId = context.recursiveValues.nodeId as? NodeID {
      return try await fetchTree(for: nodeId, in: context, with: continuation)
    } else {
      return try await fetchTree(for: rootNodeId, in: context, with: continuation)
    }
  }
}

protocol _RecursiveQueryStateProtocol: QueryStateProtocol
where
  StateValue: RecursiveValue<NodeID>,
  QueryValue: RecursiveValue<NodeID>,
  StatusValue: RecursiveValue<NodeID>
{
  associatedtype NodeID: Sendable
}

struct RecursiveQueryState<Value: RecursiveValue>: _RecursiveQueryStateProtocol {
  typealias StateValue = Value
  typealias QueryValue = Value
  typealias StatusValue = Value

  private(set) var currentValue: Value
  let initialValue: Value
  private(set) var valueUpdateCount = 0
  private(set) var valueLastUpdatedAt: Date?
  private(set) var error: (any Error)?
  private(set) var errorUpdateCount = 0
  private(set) var errorLastUpdatedAt: Date?
  private(set) var activeTasks = IdentifiedArrayOf<QueryTask<Value>>()

  init(initialValue: Value) {
    self.currentValue = initialValue
    self.initialValue = initialValue
  }

  var isLoading: Bool {
    !self.activeTasks.isEmpty
  }

  mutating func scheduleFetchTask(_ task: inout QueryTask<Value>) {
    activeTasks.append(task)
  }

  mutating func update(
    with result: Result<StateValue, any Error>,
    using context: QueryContext
  ) {
    switch result {
    case let .success(value):
      self.currentValue[id: value.nodeId] = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.queryClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.queryClock.now()
    }
  }

  mutating func update(
    with result: Result<QueryValue, any Error>,
    for task: QueryTask<QueryValue>
  ) {
    update(with: result, using: task.configuration.context)
  }

  mutating func finishFetchTask(_ task: QueryTask<QueryValue>) {
    activeTasks.remove(id: task.id)
  }

  mutating func reset(using context: QueryContext) {
    for task in activeTasks {
      task.cancel()
    }
    self = Self(initialValue: initialValue)
  }
}

extension QueryStore where State: _RecursiveQueryStateProtocol {
  func fetchTree(
    for id: State.NodeID,
    using configuration: QueryTaskConfiguration? = nil
  ) async throws -> State.QueryValue {
    var configuration = configuration ?? QueryTaskConfiguration(context: context)
    configuration.context.recursiveValues.nodeId = id
    return try await fetch(using: configuration)
  }
}

struct RecursiveQueryContextValues: Sendable {
  var nodeId: (any Sendable)?
}

extension QueryContext {
  var recursiveValues: RecursiveQueryContextValues {
    get { self[RecursiveQueryContextValuesKey.self] }
    set { self[RecursiveQueryContextValuesKey.self] = newValue }
  }

  private enum RecursiveQueryContextValuesKey: Key {
    static var defaultValue: RecursiveQueryContextValues {
      RecursiveQueryContextValues()
    }
  }
}
```

Now, we can begin using our paradigm to fetch comment threads!

```swift
struct Comment: RecursiveValue, Sendable {
  let nodeId: Int
  var children = [Comment]()
}

struct CommentThreadQuery: RecursiveQueryRequest, Hashable {
  typealias Value = Comment
  typealias NodeID = Int

  let rootNodeId: Int

  func fetchTree(
    for id: Int,
    in context: QueryContext,
    with continuation: QueryContinuation<Comment>
  ) async throws -> Comment {
    // Fetch the sub-thread from our API...
  }
}

let client = QueryClient()
let store = client.store(
  for: CommentThreadQuery(rootNodeId: 0),
  initialState: RecursiveQueryState(initialValue: Comment(nodeId: 0))
)

try await store.fetchTree(for: 10)
```

As you can see, with a bit of work we were able to extend the library with a new paradigm of fetching recursive content, and the paradigm can even utilize the exact same modifiers built for typical queries. However, do note that a full-blown implementation of this paradigm would likely add more conveniences and features that we didn't discuss here. Regardless, it shows how the library can be adapted to fit a wide range of scenarios.

## Conclusion

In this article, you learned about the 3 main paradigms of fetching data in the library. Furthermore, you also learned how you can create your own paradigm, though this is a significantly advanced topic, and generally having to do this should be rare. In the process, you learned one of the core design principles of the library, which is to derive all paradigms from ordinary queries.
