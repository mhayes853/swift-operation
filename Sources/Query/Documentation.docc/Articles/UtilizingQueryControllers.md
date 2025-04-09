# Utilizing QueryControllers

Learn how to use the `QueryController` protocol to automate fetching and state updates on your queries.

## Overview

The `QueryController` protocol gives you control over the state of a query from within a `QueryModifier` perspective itself. For instance, the `refetchOnChange` modifier uses a `QueryController` under the hood to refetch your query whenever a `FetchCondition` changes from false to true. This makes it easy to declaratively describe whenever a query should be refetched.

```swift
struct MyQuery: QueryRequest, Hashable {
  // ...
}

// Refetch whenever the network comes back online.
let query = MyQuery().refetchOnChange(of: .connected(to: NWPathMonitorObserver.shared))
```

You too can utilize the `QueryController` protocol to build such automations.

## Creating a QueryController

The `QueryController` protocol has a single function requirement that hands you an instance of `QueryControls`, and forces you to return a `QuerySubscription` to perform any cleanup work in your controller.

```swift
final class MyController<State: QueryStateProtocol>: QueryController {
  func control(with controls: QueryControls<State>) -> QuerySubscription {
    // ...
  }
}
```

The `QueryControls` data type is effectively a limited version of `QueryStore` that allows you to yield state updates from the query, and perform refetches.

```swift
final class MyController<State: QueryStateProtocol>: QueryController {
  func control(with controls: QueryControls<State>) -> QuerySubscription {
    // Yielding state.
    controls.yield(/* Construct a state value. */)

    // Yielding an error.
    controls.yield(throwing: SomeError())

    // Yielding a refetch.
    Task {
      let result: State.QueryValue? = try await controls.yieldRefetch()
    }
    return .empty
  }
}
```

> Note: `yieldRefetch` returns nil when automatic fetching is disabled on the query. In other words, if the `QueryStore`'s `isAutomaticFetchingEnabled` property is false, then you cannot yield a refetch on the query. You can check if yielding a refetch is possible on `QueryControls` via `canYieldRefetch`.

Now that we understand the basics of creating a `QueryController`, let's delve into some use cases.

## Firestore Subscriptions

Firebase allows you to both fetch and observe your data at the same time from Firestore. Using the sdk, you can model a `QueryRequest` around fetching the data, and then use a `QueryController` to subscribe to data changes and yield them from the query.

To start, we'll create a `QueryContext` property for the firestore database instance. Doing so will allow you to inject an instance of firestore that connects to a local firebase emulator for testing and development purposes.

```swift
extension QueryContext {
  var firestore: Firestore {
    get { self[FirestoreKey.self] }
    set { self[FirestoreKey.self] = newValue }
  }

  private enum FirestoreKey: Key {
    static var defaultValue: Firestore {
      .firestore()
    }
  }
}
```

When writing our query, we'll utilize `fetch` inside `FirestoreUserQuery` to fetch the initial snapshot data from firestore without making a subscription to the document reference. This will make it easy to manage loading and error states in our UI.

```swift
struct User: Codable {
  @DocumentID var id: String?
  // Other fields...
}

struct FirestoreUserQuery: QueryRequest, Hashable {
  let userId: String

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<User>
  ) async throws -> User {
    try await context.firestore.collection("users")
      .document(userId)
      .getDocument(as: User.self)
  }
}
```

In the meantime, we'll also subscribe to the publisher of a `DocumentSnapshot` inside a `QueryController`, and drop the first snapshot as the query is already fetching that data. From there on, all snapshots will be decoded into a `User`, and yielded as state through the `QueryControls`.

```swift
import Combine

final class FirestoreUserController<State: QueryStateProtocol>: QueryController {
  let userId: String

  init(userId: String) {
    self.userId = userId
  }

  func control(with controls: QueryControls<State>) -> QuerySubscription {
    let docRef = controls.context.firestore
      .collection("users")
      .document(userId)
    let cancellable = docRef.snapshotPublisher()
      .dropFirst()
      .sink { snapshot in
        controls.yield(with: Result { try snapshot.data(as: User.self) })
      }
    return QuerySubscription { cancellable.cancel() }
  }
}
```

Then, we can put it all together.

```swift
func userQuery(for id: String) -> some QueryRequest<User> {
  FirestoreUserQuery(userId: id)
    .controlled(by: FirestoreUserController(userId: id))
}

let query = userQuery(for: "123")
```

## How QueryControllers Work

We've just explored how to create `QueryController`s, and even a usecase of where you might want to use one. However, it isn't quite clear how they work internally just by seeing them attached as modifier on a query. So let's jump into how the protocol works.

### QueryControls

As stated previously, the `QueryControls` can be thought of as a limited version of `QueryStore`. In fact, it uses a weak reference to a `QueryStore` under the hood, and only exposes a select few APIs from the store to give you control over the query.

From a design perspective, this makes sense considering the notion of automatic fetching. When automatic fetching is disabled on a query store, all state updates to the query must come either from updating the state manually, or by explicitly calling `fetch` on the store manually. Controllers are inherently "running in the background" and are not guaranteed to refetch the query based on manual user interactions, therefore `yieldRefetch` falls under the bin of automatic fetching.

### The QueryController Modifier

Controllers are powered by the `QueryModifier` system. In fact, the modifier is quite simple.

```swift
struct QueryControllerModifier<
  Query: QueryRequest,
  Controller: QueryController<Query.State>
>: QueryModifier {
  let controller: Controller

  func setup(context: inout QueryContext, using query: Query) {
    context.queryControllers.append(self.controller)
    query.setup(context: &context)
  }

  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await query.fetch(in: context, with: continuation)
  }
}
```

All we do here is append to a context property that holds all the controllers. In fact, you can even access this property yourself.

```swift
extension QueryContext {
  public var queryControllers: [any QueryController] {
    get { self[QueryControllersKey.self] }
    set { self[QueryControllersKey.self] = newValue }
  }

  private enum QueryControllersKey: Key {
    static var defaultValue: [any QueryController] { [] }
  }
}
```

This context property is used by a `QueryStore` to find all the controllers for your query, create an appropriate `QueryControls` instance, and then call `control` on them. This happens when a `QueryStore` is initialized. When the `QueryStore` is deallocated, it will cancel the subscription returned from `control`.

## Conclusion

In this article, you learned about the `QueryController` protocol, and what it represents in the library. You learned how to create controllers, and when to use them. You even learned the basics of how they work under the hood.
