# Creating a Custom Operation Type

Learn about how to create a custom operation type. In this article, we'll explore a simple recursive operation.

## Overview

The library provides 3 operation types that are applicable to different situations:

1. **Queries**: The most basic type that supports fetching any kind of data.
2. **Paginated Requests**: A type for fetching paginated data that can be put into an infinite scrollable list piece by piece.
3. **Mutations**: A type for updating data asynchronously, such as performing a POST request to an API.

All types are built on top of the ``OperationRequest`` protocol, and so all modifiers and functionallity that works with a generic `OperationRequest` will also work with all 3 types.

You can also build your own operation types to support cases that the built-in types don't support by inheriting from the `OperationRequest` protocol. We'll explore how one could make a simplified type for fetching recursive data such as nested comments in a comment thread. This is an advanced topic, but the built-in type should support nearly every case you encounter in your app, so implementing your own type should be relatively rare. Nevertheless, this article still serves as insight into how the built-in types work under the hood, and should further your understanding of the internals of the library.

## Building a Recursive Operation Type

We'll first note that our operation data is tree-like, and we'll need the ability to fetch subtrees of each branch. Inherently, this means that we'll need to be able to identify a node of the tree in our operation.

Therefore, our first move will be to create a protocol that inherits ``StatefulOperationRequest``. `StatefulOperationRequest` inherits from `OperationRequest` and adds a couple of requirements around managing state that ensures conformances of our custom operation type are compatible with ``OperationStore``.

```swift
protocol RecursiveRequest: StatefulOperationRequest {
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

Then we can update `RecursiveRequest` to ensure that the `Value` generic conforms to `RecursiveValue`.

```diff
- protocol RecursiveRequest<NodeID>: StatefulOperationRequest {
+ protocol RecursiveRequest<NodeValue, NodeID>: StatefulOperationRequest
+ where Value == NodeValue {
+ associatedtype NodeValue: RecursiveValue<NodeID>
  associatedtype NodeID: Sendable
}
```

Given that we'll be fetching branches of the tree, we'll need to make a fetch requirement for fetching a particular subtree on `RecursiveRequest`.

```diff
protocol RecursiveRequest<NodeValue, NodeID>: StatefulOperationRequest
where Value == NodeValue {
  associatedtype NodeValue: RecursiveValue<NodeID>
  associatedtype NodeID: Sendable

+  func fetchTree(
+    isolation: isolated (any Actor)?,
+    for id: NodeID,
+    in context: OperationContext,
+    with continuation: OperationContinuation<NodeValue>
+  ) async throws -> NodeValue
}
```

That requirement allows us to fetch a tree when given a specific `NodeID`. However, how do we determine what the root id is? It turns out that we'll also need a requirement for that too similar to how `PaginatedRequest` also has an `initialPageId` requirement.

```diff
protocol RecursiveRequest<NodeValue, NodeID>: StatefulOperationRequest
where Value == NodeValue {
  associatedtype NodeValue: RecursiveValue<NodeID>
  associatedtype NodeID: Sendable

+ var rootNodeId: NodeID { get }

  func fetchTree(
    isolation: isolated (any Actor)?,
    for id: NodeID,
    in context: OperationContext,
    with continuation: OperationContinuation<NodeValue>
  ) async throws -> NodeValue
}
```

At this point, we've defined how recursive requests work on the data fetching level. Yet we haven't described how managing the state for the operation type works. All built-in operation types come with a value type that conforms to the ``OperationState`` protocol such as `PaginatedState`. Similarly, we'll need a state type that describes how the state is managed for our recursive operation.

```swift
struct RecursiveState<Value: RecursiveValue>: OperationState {
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
  private(set) var activeTasks = IdentifiedArrayOf<OperationTask<Value, any Error>>()

  init(initialValue: Value) {
    self.currentValue = initialValue
    self.initialValue = initialValue
  }

  // We'll come back to the function requirements later...
}
```

This means that we'll need to update the `RecursiveRequest` protocol by constraining the type of state we can use on the protocol.

```diff
protocol RecursiveRequest<NodeValue, NodeID>: StatefulOperationRequest
- where Value == NodeValue {
+ where Value == NodeValue, State == RecursiveState<Value> {
  associatedtype NodeValue: RecursiveValue<NodeID>
  associatedtype NodeID: Sendable

  var rootNodeId: NodeID { get }

  func fetchTree(
    isolation: isolated (any Actor)?,
    for id: NodeID,
    in context: OperationContext,
    with continuation: OperationContinuation<NodeValue>
  ) async throws -> NodeValue
}
```

Now with all of our basic types in place, we'll almost certainly want to provide helper methods on `OperationStore` that allow us to fetch a specific subtree. We can do this by extending the store with a constraint that ensures that the `State` generic is some kind of `RecursiveState` instance.

```swift
// 🔴 This is a compiler error.
extension OperationStore where State == RecursiveState {
  // More to come...
}
```

However, we'll see that we need to specify generics for `RecursiveState` in the extension. However, we want this extension to work for any kind of `RecursiveState`, and we don't really care about any concrete generics. We can solve this by making an intermediate protocol, and conforming `RecursiveState` to it. Then, we should be able to extend the `OperationStore` in a way that constrains the `State` generic to `RecursiveState`.

```swift
protocol _RecursiveStateProtocol: OperationState
where
  StateValue: RecursiveValue<NodeID>,
  OperationValue: RecursiveValue<NodeID>,
  StatusValue: RecursiveValue<NodeID>
{
  associatedtype NodeID: Sendable
}

extension RecursiveState: _RecursiveStateProtocol {
  typealias NodeID = Value.NodeID
}

extension OperationStore where State: _RecursiveStateProtocol {
  // More to come...
}
```

Now that allows us to define a method to fetch a subtree of the operation state on `OperationStore`.

```swift
extension OperationStore where State: _RecursiveStateProtocol {
  func fetchTree(
    for id: State.NodeID,
    using context: OperationContext? = nil
  ) async throws -> State.Value {
    // ...
  }
}
```

`OperationStore` by default only has a `run` method for running the operation and returning the result in its entirety. However, in our case we're merely trying to fetch a part of the overall data by focusing on a subtree. To get around this, we'll need to rely on the ``OperationContext`` parameter in `fetchTree`. If no context is provided, we can simply create one with our store's context.

```swift
extension OperationStore where State: _RecursiveStateProtocol {
  func fetchTree(
    for id: State.NodeID,
    using context: OperationContext? = nil
  ) async throws -> State.Value {
    var context = context ?? self.context
    // More to come...
  }
}
```

In order to pass the node id to the operation, we'll need to create a custom `OperationContext` property. If you're familiar with how to create custom `EnvironmentValues` properties in SwiftUI, it's a very similar process for the `OperationContext`.

```swift
struct RecursiveContextValues: Sendable {
  var nodeId: (any Sendable)?
}

extension OperationContext {
  var recursiveValues: RecursiveContextValues {
    get { self[RecursiveContextValuesKey.self] }
    set { self[RecursiveContextValuesKey.self] = newValue }
  }

  private enum RecursiveContextValuesKey: Key {
    static var defaultValue: RecursiveContextValues {
      RecursiveContextValues()
    }
  }
}
```

Now we can use our new context property to pass our node id through to the operation.

```swift
extension OperationStore where State: _RecursiveStateProtocol {
  func fetchTree(
    for id: State.NodeID,
    using context: OperationContext? = nil
  ) async throws -> State.Value {
    var context = context ?? self.context
    context.recursiveValues.nodeId = id
    return try await run(using: context)
  }
}
```

The first thing that happens when `run` is called on an `OperationStore` is that the store will try to schedule an `OperationTask` on the current `State`. So we'll implement `scheduleFetchTask` on `RecursiveState`.

```swift
struct RecursiveState<Value: RecursiveValue>: OperationState {
  // ...

  var isLoading: Bool {
    !self.activeTasks.isEmpty
  }

  mutating func scheduleFetchTask(_ task: inout OperationTask<Value, any Error>) {
    activeTasks.append(task)
  }

  // More to come...
}
```

> Note: In a real implementation, we may want to see if we are also fetching subtrees for the parent nodes and wait for those tasks to finish first before fetching the subtree. For that we can use the ``OperationTask/schedule(after:)-(OperationTask<V,E>)`` API.

As we can see here, we just need to append the task to our list of active tasks on the state, and we can even compute `isLoading` by checking if there are any active tasks on the state.

After scheduling the task on the state, the `OperationStore` will then try to invoke `run` on the underlying `RecursiveRequest` protocol. However, we have no default implementation of `run` on the protocol, so conforming types will have to implement it manually. Instead, let's fill in a default implementation that calls down to `fetchTree` such that we don't burden recursive requests with having to implement it manually.

```swift
extension RecursiveRequest {
  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value, any Error>
  ) async throws -> Value {
    if let nodeId = context.recursiveValues.nodeId as? NodeID {
      return try await fetchTree(
        isolation: isolation,
        for: nodeId,
        in: context,
        with: continuation
      )
    } else {
      // If we have no node id in the context (eg. We called
      // `run` directly the `OperationStore` instead of `fetchTree`),
      // we'll assume we're refetching from the root.
      return try await fetchTree(
        isolation: isolation,
        for: rootNodeId,
        in: context,
        with: continuation
      )
    }
  }
}
```

As the operation runs, results will be yielded from the operation either through ``OperationContinuation`` or through returning the final value. When this happens, the `OperationStore` will invoke a method on the `State` signifying that a result was yielded from the operation. Therefore, we'll implement the `update` requirement for `RecursiveState` that handles a result paired with the associated ``OperationTask``.

```swift
struct RecursiveState<Value: RecursiveValue>: OperationState {
  // ...

  mutating func update(
    with result: Result<QueryValue, any Error>,
    for task: OperationTask<QueryValue, any Error>
  ) {
    let context = task.configuration.context
    switch result {
    case let .success(value):
      self.currentValue[id: value.nodeId] = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.operationClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.operationClock.now()
    }
  }

  // More to come...
}
```

> Note: We'll use the operation clock in the context here to compute the dates for `valueLastUpdatedAt` and `errorLastUpdatedAt`. This allows the clock to be overriden in testing such that a deterministic date is provided.

Once the operation itself stops running, the `OperationStore` will indicate to the state that the task has been finished. This is implemented through another requirement on `RecursiveState`. All we have to do here is remove the finished task from the list of active tasks.

```swift
struct RecursiveState<Value: RecursiveValue>: OperationState {
  // ...

  mutating func finishFetchTask(_ task: OperationTask<QueryValue, any Error>) {
    activeTasks.remove(id: task.id)
  }

  // More to come...
}
```

At this point the basics of our recursive operation type are implemented. Yet there are still 2 more requirements that we need to implement on `RecursiveState`.

### Setting State Manually

`OperationState` has 2 `update` requirements. The first is when the in progress operation yields a value when fetching, and this is associated with an `OperationTask`. However, the `OperationStore` also allows us to set the state value of the operation directly, which is useful for optimistic UI updates and much more. For this, `OperationState` has another update requirement, this time taking a result to the `StateValue` with an `OperationContext`. Implementing this is almost identical to the other `update` requirement on `RecursiveState`.

```swift
struct RecursiveState<Value: RecursiveValue>: OperationState {
  // ...

  mutating func update(
    with result: Result<StateValue, any Error>,
    using context: OperationContext
  ) {
    switch result {
    case let .success(value):
      self.currentValue[id: value.nodeId] = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.operationClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.operationClock.now()
    }
  }

  // More to come...
}
```

In fact, we can even utilize this implementation in the other `update` requirement since `StateValue` and `OperationValue` are equivalent in `RecursiveState`.

```diff
struct RecursiveState<Value: RecursiveValue>: OperationState {
  // ...

  mutating func update(
    with result: Result<OperationValue, any Error>,
    for task: OperationTaskOperationValueQueryValue, any Errore>
  ) {
-  switch result {
-   case let .success(value):
-     self.currentValue[id: value.nodeId] = value
-     self.valueUpdateCount += 1
-     self.valueLastUpdatedAt = context.operationClock.now()
-     self.error = nil
-   case let .failure(error):
-     self.error = error
-     self.errorUpdateCount += 1
-     self.errorLastUpdatedAt = context.operationClock.now()
-   }
+   update(with: result, using: task.configuration.context)
  }

  // More to come...
}
```

### Resetting State

It's also possible to reset the entire `State` on an `OperationStore` vian ``OperationStore/resetState(using:)``. When doing this, the store calls out to the `State` to reset itself, which is represented via a `reset` requirement on `OperationState`. When implementing this method you will reset the properties in your state to their initial values, and then you will return a `ResetEffect` with the `OperationTask` instances that you want to cancel. The `OperationStore` is responsible to for cancelling the tasks themselves. This is because the store is designed to be the runtime for the operation, whilst the state is meant to be a plain data type that represents the current state of the operation.

```swift
struct RecursiveState<Value: RecursiveValue>: OperationState {
  // ...

  mutating func reset(using context: OperationContext) -> ResetEffect {
    let tasksToCancel = activeTasks
    self = Self(initialValue: initialValue)
    return ResetEffect(tasksToCancel: tasksToCancel)
  }
}
```

All of those cancelled tasks will throw a `CancellationError`, however those errors will not be reflected in your reset state as `OperationStore` is smart enough to know that resetting means completely setting a clean slate.

### Concluding Our Custom Operation Type

At this point, we've implemented a basic operation type! Here's all the code that we wrote below.

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

protocol RecursiveRequest<NodeValue, NodeID>: StatefulOperationRequest
where Value == NodeValue, State == RecursiveState<Value> {
  associatedtype NodeValue: RecursiveValue<NodeID>
  associatedtype NodeID: Sendable

  var rootNodeId: NodeID { get }

  func fetchTree(
    isolation: isolated (any Actor)?,
    for id: NodeID,
    in context: OperationContext,
    with continuation: OperationContinuation<NodeValue, any Error>
  ) async throws -> NodeValue
}

extension RecursiveRequest {
  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<NodeValue, any Error>
  ) async throws -> NodeValue {
    if let nodeId = context.recursiveValues.nodeId as? NodeID {
      return try await fetchTree(
        isolation: isolation,
        for: nodeId,
        in: context,
        with: continuation
      )
    } else {
      return try await fetchTree(
        isolation: isolation,
        for: rootNodeId,
        in: context,
        with: continuation
      )
    }
  }
}

protocol _RecursiveStateProtocol: OperationState
where
  StateValue: RecursiveValue<NodeID>,
  OperationValue: RecursiveValue<NodeID>,
  StatusValue: RecursiveValue<NodeID>
{
  associatedtype NodeID: Sendable
}

struct RecursiveState<
  Value: RecursiveValue
>: _RecursiveStateProtocol {
  typealias StateValue = Value
  typealias OperationValue = Value
  typealias StatusValue = Value

  private(set) var currentValue: Value
  let initialValue: Value
  private(set) var valueUpdateCount = 0
  private(set) var valueLastUpdatedAt: Date?
  private(set) var error: (any Error)?
  private(set) var errorUpdateCount = 0
  private(set) var errorLastUpdatedAt: Date?
  private(set) var activeTasks = IdentifiedArrayOf<OperationTask<Value, any Error>>()

  init(initialValue: Value) {
    self.currentValue = initialValue
    self.initialValue = initialValue
  }

  var isLoading: Bool {
    !self.activeTasks.isEmpty
  }

  mutating func scheduleFetchTask(_ task: inout OperationTask<Value, any Error>) {
    activeTasks.append(task)
  }

  mutating func update(
    with result: Result<StateValue, any Error>,
    using context: OperationContext
  ) {
    switch result {
    case let .success(value):
      self.currentValue[id: value.nodeId] = value
      self.valueUpdateCount += 1
      self.valueLastUpdatedAt = context.operationClock.now()
      self.error = nil
    case let .failure(error):
      self.error = error
      self.errorUpdateCount += 1
      self.errorLastUpdatedAt = context.operationClock.now()
    }
  }

  mutating func update(
    with result: Result<OperationValue, any Error>,
    for task: OperationTask<OperationValue, any Error>
  ) {
    update(with: result, using: task.context)
  }

  mutating func finishFetchTask(_ task: OperationTask<OperationValue, any Error>) {
    activeTasks.remove(id: task.id)
  }

  mutating func reset(using context: OperationContext) -> ResetEffect {
    let tasksToCancel = activeTasks
    self = Self(initialValue: initialValue)
    return ResetEffect(tasksToCancel: tasksToCancel)
  }
}

extension OperationStore where State: _RecursiveStateProtocol {
  func fetchTree(
    for id: State.NodeID,
    using context: OperationContext? = nil
  ) async throws -> State.OperationValue {
    var context = context ?? self.context
    context.recursiveValues.nodeId = id
    return try await run(using: context)
  }
}

struct RecursiveContextValues: Sendable {
  var nodeId: (any Sendable)?
}

extension OperationContext {
  var recursiveValues: RecursiveContextValues {
    get { self[RecursiveContextValuesKey.self] }
    set { self[RecursiveContextValuesKey.self] = newValue }
  }

  private enum RecursiveContextValuesKey: Key {
    static var defaultValue: RecursiveContextValues {
      RecursiveContextValues()
    }
  }
}
```

Now, we can begin using our type to fetch comment threads!

```swift
struct Comment: RecursiveValue, Sendable {
  let nodeId: Int
  var children = [Comment]()
}

extension Comment {
  static func threadQuery(
    for id: Int
  ) -> some RecursiveRequest<Comment, Int> {
    ThreadQuery(rootNodeId: id)
  }

  struct ThreadQuery: RecursiveRequest, Hashable {
    let rootNodeId: Int

    func fetchTree(
      isolation: isolated (any Actor)?,
      for id: Int,
      in context: OperationContext,
      with continuation: OperationContinuation<Comment, any Error>
    ) async throws -> Comment {
      // Fetch the sub-thread from our API...
    }
  }
}

let client = OperationClient()
let store = client.store(
  for: Comment.threadQuery(for: 0),
  initialState: RecursiveState(initialValue: Comment(nodeId: 0))
)

try await store.fetchTree(for: 10)
```

As you can see, with a bit of work we were able to extend the library with a new operation type of fetching recursive content, and the type can even utilize the exact same modifiers built for any kind of operation. However, do note that a full-blown implementation of this operation type would likely add more conveniences and features that we didn't discuss here (eg. default values, typed throws, `OperationStore` initializers, proper parallelism, etc.). Regardless, it shows how the library can be adapted to fit a wide range of scenarios.

## Conclusion

In this article, you learned about how to create a custom that can be integrated with the library. Whilst an advanced topic, and not a feature that you would use in day-to-day usage of the library, it serves as a tool to further your understanding of how the built-in operation types work in the library.
