# Query Pattern Matching and State Management

Learn how to utilize ``OperationPath`` and ``OperationClient`` to pattern match queries and manage state.

## Overview

While the library provides powerful tools to help you fetch data, managing consistency of the fetched data is a whole other challenge, and often a more complicated one than fetching the data itself.

For example, let's consider the scenario of a typical social platform where users can send friend requests to each other, and where users can see their and others' list of friends and requested friends. The `relationship` field for each user in the list will represent the current active user's relationship to that user. We may model 1 query and 1 mutation in this scenario. For the friends list, we may utilize an infinite query, and sending a friend request could be modeled as a mutation.

```swift
struct User: Sendable {
  enum Relationship {
    case notFriends
    case friendRequestSent
    case friendRequestReceived
    case friends
    case currentUser
  }

  let id: Int
  var relationship: Relationship

  // ...
}

extension User {
  static func friendsQuery(
    for id: Int
  ) -> some PaginatedRequest<Int, [Self]> {
    FriendsQuery(userId: id)
  }

  struct FriendsQuery: PaginatedRequest, Hashable {
    typealias PageID = Int
    typealias PageValue = [User]

    let userId: Int
    let initialPageId = 0

    func pageId(
      after page: PaginatedPage<Int, [User]>,
      using paging: PaginatedPaging<Int, [User]>,
      in context: OperationContext
    ) -> Int? {
      page.id + 1
    }

    func fetchPage(
      using paging: PaginatedPaging<Int, [User]>,
      in context: OperationContext,
      with continuation: OperationContinuation<[User]>
    ) async throws -> [User] {
      try await fetchFriends(userId: userId, page: paging.pageId)
    }
  }
}

extension User {
  static let sendFriendRequestMutation = SendFriendRequestMutation()

  struct SendFriendRequestMutation: MutationRequest, Hashable {
    typealias Value = Void

    struct Arguments: Sendable {
      let userId: Int
    }

    func mutate(
      with arguments: Arguments,
      in context: OperationContext,
      with continuation: OperationContinuation<Void>
    ) async throws {
      try await sendFriendRequest(userId: arguments.userId)
    }
  }
}
```

The problem here is that when `User.SendFriendRequestMutation` runs successfully, all screens that utilize `User.FriendsQuery` are now displaying outdated data as we haven't explicitly updated the query state of those screens to indicate that the friend request was sent.

Utilizing both ``OperationClient`` in conjunction with ``OperationPath`` will make managing this state straight forward.

## Marking Friend Requests As Sent

To start, we'll want to define a reusable transformation on the value of `User.FriendsQuery` that transforms the appropriate user relationship inside the infinite query pages. When updating the state of the query directly, we'll call this reusable transform method.

```swift
extension PaginatedPages<Int, [User]> {
  func updateRelationship(
    for userId: Int,
    to relationship: User.Relationship
  ) -> Self {
    self.map { page in
      var page = page
      page.value = page.value.map { user in
        var user = user
        if user.id == userId {
          user.relationship = relationship
        }
        return user
      }
      return page
    }
  }
}
```

## Updating Query State After a Mutation

When a user sends a friend request to a user, we'll want to update the friends list query of the receiving user. The most basic approach for handling this is to reach into the ``OperationContext`` that's passed to the mutation, and then grab the `OperationClient` from it. From there, we can peak into the ``OperationStore`` for the corresponding friend list query and update its state.

```swift
struct SendFriendRequestMutation: MutationRequest, Hashable {
  // ...

  func mutate(
    with arguments: Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<Void>
  ) async throws {
    try await sendFriendRequest(userId: arguments.userId)

    // Friend request sent successfully, now update the friends list.
    guard let client = context.operationClient else { return }
    let query = UserFriendsQuery(userId: arguments.userId)
    let store = client.store(for: query)
    store.withExclusiveAccess {
      store.currentValue = store.currentValue.updateRelationship(
        for: arguments.userId,
        to: .friendRequestSent
      )
    }
  }
}
```

This works, however it's considerably likely that we'll have multiple instances of `User.FriendsQuery` that need to display the relationship status between the current user and the receiving user. Unfortunately, taking stores off the `OperationClient` in a loop is quite inefficient, however the library provides better tools for managing this.

## OperationPath and Store Pattern Matching

To get around the aforementioned performance issue, we can utilize a `OperationPath` to pattern match the existing `OperationStore`s inside the `OperationClient`.

``QueryRequest``, and all protocols that inherit from it such as ``PaginatedRequest`` and ``MutationRequest`` have an optional `path` requirement. When your query type conforms to Hashable, this requirement is automatically implemented as follows.

```swift
extension OperationRequest where Self: Hashable {
  var path: OperationPath { [self] }
}
```

This implementation, while convenient, does not take advantage of the full power of `OperationPath`. To understand why, we'll need to briefly cover what a `OperationPath` represents.

### OperationPath Basics

At the very least, you can think of a `OperationPath` as an identifier for a query. This identifier is essentially an array of `Hashable` elements that uniquely identify the query. Under the hood, `OperationClient` utilizes a query's path as key into a dictionary of `OperationStore`s. If you're familiar with [Tanstack Query](https://tanstack.com/query/latest/docs/framework/react/guides/query-keys), `OperationPath` is analogous to the `queryKey` property.

If we remove the conformance to `Hashable` on `User.FriendsQuery`, we'll be forced to fill in a custom `OperationPath`.

```swift
struct FriendsQuery: PaginatedRequest {
  typealias PageID = Int
  typealias PageValue = [User]

  let userId: Int

  var path: OperationPath {
    ["user-friends", userId]
  }

  // ...
}
```

In this case, we have 2 identifying components of the query. First, we use a string to represent that this query is for a list of friends, and secondly we use the `userId` to represent the user for whom we are fetching friends.

The real power of splitting the path into an array of multiple components is that you can pattern match the query utilizing a prefix. For instance, you can get access to the `OperationStore`s for all user friend list queries on a `OperationClient` by checking if the path starts with `["user-friends"]`.

```swift
OperationClient.stores(
  matching: ["user-friends"],
  of: User.FriendsQuery.State.self
)
```

This will return back a `[OperationPath: OperationStore<User.FriendsQuery.State>]` that you can use to access the current state of all friends list queries in our app.

> Note: An ``OpaqueOperationStore`` is a fully type erased `OperationStore`. You can still access and mutate the state on the store, but you will have to make the appropriate casts from `any Sendable` to the type of data you're working with.

Now that we have a basic understanding of `OperationPath`, we can explore how to use it effectively in our social app.

### Pattern Matching in SendFriendRequestMutation

With a basic understanding of `OperationPath`, it is actually quite simple to update the state for all `User.FriendsQuery` instances in our app when sending a friend request succeeds.

```swift
struct SendFriendRequestMutation: MutationRequest, Hashable {
  // ...

  func mutate(
    with arguments: Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<Void>
  ) async throws {
    try await sendFriendRequest(userId: arguments.userId)

    // Friend request sent successfully, now update all
    // friends lists in the app.
    guard let client = context.operationClient else { return }
    let stores = client.stores(
      matching: ["user-friends"],
      of: User.FriendsQuery.State.self
    )
    for store in stores {
      store.withExclusiveAccess {
        store.currentValue = store.currentValue.updateRelationship(
          for: arguments.userId,
          to: .friendRequestSent
        )
      }
    }
  }
}
```

Now, any screen in our app that displays a friends list will automatically update to reflect the new user relationship status.

## Optimistic UI Updates

In our above example, we only update all the friends lists after we've successfully managed to send a friend request through our API. However, we can also use a similar technique to apply optimistic UI updates, such that the result of the mutation is immediately visible in the UI, but if it fails then it gets reverted.

```swift
struct SendFriendRequestMutation: MutationRequest, Hashable {
  // ...

  func mutate(
    with arguments: Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<Void>
  ) async throws {
    // Optimistically update the user relationships, and reset them to the
    // default state if the mutation fails.
    do {
      updateRelationships(
        for: arguments.userId,
        to: .friendRequestSent,
        in: context
      )
      try await sendFriendRequest(userId: arguments.userId)
    } catch {
      updateRelationships(
        for: arguments.userId,
        to: .notFriends,
        in: context
      )
      throw error
    }
  }

  private func updateRelationships(
    to relationship: User.Relationship,
    userId: Int,
    in context: OperationContext
  ) {
    guard let client = context.operationClient else { return }
    let stores = client.stores(
      matching: ["user-friends"],
      of: User.FriendsQuery.State.self
    )
    for store in stores {
      store.withExclusiveAccess {
        store.currentValue = store.currentValue.updateRelationship(
          for: arguments.userId,
          to: relationship
        )
      }
    }
  }
}
```

## Refetching Queries

The above examples demonstrate how to directly update the state for queries during a mutation. However, sometimes it's for the best to just refetch the affected queries instead of updating the state directly. For instance, maybe the updated state cannot be determined solely based on the mutation data, and the only the server has the ability to determine the updated state. Regardless of reason, it's quite easy to perform refetching using the same pattern matching technique shown above.

```swift
struct SendFriendRequestMutation: MutationRequest, Hashable {
  // ...

  func mutate(
    with arguments: Arguments,
    in context: OperationContext,
    with continuation: OperationContinuation<Void>
  ) async throws {
    try await sendFriendRequest(userId: arguments.userId)

    // Friend request sent successfully, now refetch all
    // friends lists in the app.
    guard let client = context.operationClient else { return }
    Task {
      try await withThrowingTaskGroup(of: Void.self) { group in
        for store in client.stores(matching: ["user-friends"]) {
          group.addTask { try await store.fetch() }
        }
      }
    }
  }
}
```

## Conclusion

In this article, you learned how to use the library to manage asynchronous data fetched by your queries. `OperationClient` can hold the `OperationStore` instances for your queries, and you can utilize `OperationPath` to pattern match these stores. In addition to setting the value of a `OperationStore` directly, you also can decide to refetch the data for a query in order to keep it's state as fresh as possible.
