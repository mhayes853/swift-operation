# Creating a Custom Fetching Paradigm

Learn about how to create a custom data fetching paradigm. In this article, we'll explore a simple recursive fetching paradigm.

## Overview

The library provides 3 query paradigms that are applicable to different situations:

1. **Queries**: The most basic paradigm that supports fetching any kind of data.
2. **Infinite Queries**: A paradigm for fetching paginated data that can be put into an infinite scrollable list piece by piece.
3. **Mutations**: A paradigm for updating data asynchronously, such as performing a POST request to an API.

Infinite queries and mutations are both built directly on top of ordinary queries, and so all modifiers and functionallity that works with traditional queries will also work with those 2 paradigms.

You can also build your own data fetching paradigms to support cases that the built-in paradigms don't support. We'll explore how one could make a simplified paradigm for fetching recursive data such as nested comments in a comment thread. This is an advanced topic, but the built-in paradigms should support nearly every case you encounter in your app, so implementing your own paradigm should be relatively rare. Nevertheless, this article still serves as insight into how the built-in paradigms work under the hood, and should further your understanding of the internals of the library.

## Building a Recursive Data Fetching Paradigm

We'll first note that our query data is tree-like, and we'll need the ability to fetch subtrees of each branch. Inherently, this means that we'll need to be able to identify a node of the tree in our query.

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
    get { /* Do a tree traversal... */ }
    set { /* Do a tree traversal... */ }
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
    var configuration = configuration
      ?? QueryTaskConfiguration(context: context)
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
    var configuration = configuration
      ?? QueryTaskConfiguration(context: context)
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
      return try await fetchTree(
        for: nodeId,
        in: context,
        with: continuation
      )
    } else {
      // If we have no node id in the context (eg. We called
      // `fetch` directly the `QueryStore` instead of `fetchTree`),
      // we'll assume we're refetching from the root.
      return try await fetchTree(
        for: rootNodeId,
        in: context,
        with: continuation
      )
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
    let context = task.configuration.context
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

It's also possible to reset the entire `State` on a `QueryStore` via ``QueryStore/resetState(using:)``. When doing this, the store calls out to the `State` to reset itself, which is represented via a `reset` requirement on `QueryStateProtocol`. When implementing this method you will reset the properties in your state to their initial values, and then you will return a `ResetEffect` with the `QueryTask` instances that you want to cancel. The `QueryStore` is responsible to for cancelling the tasks themselves. This is because the store is designed to be the runtime for the query, whilst the state is meant to be a plain data type that represents the current state of the query.

```swift
struct RecursiveQueryState<Value: RecursiveValue>: QueryStateProtocol {
  // ...

  mutating func reset(using context: QueryContext) -> ResetEffect {
    let tasksToCancel = activeTasks
    self = Self(initialValue: initialValue)
    return ResetEffect(tasksToCancel: tasksToCancel)
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
      return try await fetchTree(
        for: nodeId,
        in: context,
        with: continuation
      )
    } else {
      return try await fetchTree(
        for: rootNodeId,
        in: context,
        with: continuation
      )
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

struct RecursiveQueryState<
  Value: RecursiveValue
>: _RecursiveQueryStateProtocol {
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

  mutating func reset(using context: QueryContext) -> ResetEffect {
    let tasksToCancel = activeTasks
    self = Self(initialValue: initialValue)
    return ResetEffect(tasksToCancel: tasksToCancel)
  }
}

extension QueryStore where State: _RecursiveQueryStateProtocol {
  func fetchTree(
    for id: State.NodeID,
    using configuration: QueryTaskConfiguration? = nil
  ) async throws -> State.QueryValue {
    var configuration = configuration
      ?? QueryTaskConfiguration(context: context)
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

extension Comment {
  static func threadQuery(
    for id: Int
  ) -> some RecursiveQueryRequest<Comment, Int> {
    ThreadQuery(rootNodeId: id)
  }

  struct ThreadQuery: RecursiveQueryRequest, Hashable {
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
}

let client = QueryClient()
let store = client.store(
  for: Comment.threadQuery(for: 0),
  initialState: RecursiveQueryState(initialValue: Comment(nodeId: 0))
)

try await store.fetchTree(for: 10)
```

As you can see, with a bit of work we were able to extend the library with a new paradigm of fetching recursive content, and the paradigm can even utilize the exact same modifiers built for typical queries. However, do note that a full-blown implementation of this paradigm would likely add more conveniences and features that we didn't discuss here. Regardless, it shows how the library can be adapted to fit a wide range of scenarios.

## Conclusion

In this article, you learned about how to create a custom data fetching paradigm that can be integrated with the library. Whilst an advanced topic, and not a feature that you would use in day-to-day usage of the library, it serves as a tool to further your understanding of how the built-in paradigms work in the library.
