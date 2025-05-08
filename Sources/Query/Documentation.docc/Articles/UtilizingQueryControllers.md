# Utilizing QueryControllers

Learn how to use the ``QueryController`` protocol to automate fetching and state updates on your queries.

## Overview

The `QueryController` protocol gives you control over the state of a query from within a ``QueryModifier`` perspective itself. For instance, the ``QueryRequest/refetchOnChange(of:)`` modifier uses a `QueryController` under the hood to refetch your query whenever a `FetchCondition` changes from false to true. This makes it easy to declaratively describe whenever a query should be refetched.

```swift
struct MyQuery: QueryRequest, Hashable {
  // ...
}

// Refetch whenever the network comes back online.
let query = MyQuery().refetchOnChange(
  of: .connected(to: NWPathMonitorObserver.shared)
)
```

You too can utilize the `QueryController` protocol to build such automations.

## Creating a QueryController

The `QueryController` protocol has a single function requirement that hands you an instance of ``QueryControls``, and forces you to return a ``QuerySubscription`` to perform any cleanup work in your controller.

```swift
final class MyController<State: QueryStateProtocol>: QueryController {
  func control(with controls: QueryControls<State>) -> QuerySubscription {
    // ...
  }
}
```

The `QueryControls` data type is effectively a limited version of ``QueryStore`` that allows you to yield state updates from the query, and perform refetches.

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

> Note: ``QueryControls/yieldRefetch(with:)`` returns nil when automatic fetching is disabled on the query. In other words, if ``QueryStore/isAutomaticFetchingEnabled`` property is false, then you cannot yield a refetch on the query. You can check if yielding a refetch is possible on `QueryControls` via ``QueryControls/canYieldRefetch``.

Now that we understand the basics of creating a `QueryController`, let's delve into some use cases.

## Firestore Subscriptions

Firebase allows you to both fetch and observe your data at the same time from Firestore. Using the sdk, you can model a ``QueryRequest`` around fetching the data, and then use a `QueryController` to subscribe to data changes and yield them from the query.

To start, we'll create a ``QueryContext`` property for the firestore database instance. Doing so will allow you to inject an instance of firestore that connects to a local firebase emulator for testing and development purposes.

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

extension User {
  static func query(
    for id: String
  ) -> some QueryRequest<Self, Query.State> {
    // More to come...
  }

  struct Query: QueryRequest, Hashable {
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
}
```

In the meantime, we'll also subscribe to the publisher of a `DocumentSnapshot` inside a `QueryController`, and drop the first snapshot as the query is already fetching that data. From there on, all snapshots will be decoded into a `User`, and yielded as state through the `QueryControls`.

```swift
import Combine

final class FirestoreUserController<
  State: QueryStateProtocol
>: QueryController {
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
extension User {
  static func query(
    for id: String
  ) -> some QueryRequest<Self, Query.State> {
    Query(userId: id).controlled(by: FirestoreUserController(userId: id))
  }

  // ...
}
```

## Conclusion

In this article, you learned about the `QueryController` protocol, and what it represents in the library. You learned how to create controllers, and how they can be utilized to create reusable pieces of logic that invoke your queries.
