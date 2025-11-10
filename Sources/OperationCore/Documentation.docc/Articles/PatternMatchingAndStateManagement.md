# Pattern Matching and State Management

Learn how to utilize ``OperationPath`` and ``OperationClient`` to pattern match operations and manage state.

## Overview

While the library provides powerful tools to help you fetch data and run other complex operations, managing consistency of the fetched data is a whole other challenge, and often a more complicated one than fetching the data itself.

The `@SharedOperation` property wrapper is the primary manner in which you observe the state of an operation in your application. In fact, when multiple instances of the property wrapper are in-memory, they will refer to the same ``OperationStore`` under the hood. This means that your operation is efficiently observed in the sense that the state of one operation run is reported to multiple `@SharedOperation` property wrapper instances.

```swift
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

However, this is just the tip of the iceberg. In many cases, the result of running some operation should affect the data represented by other operations. 

Consider the scenario of a typical social platform where users can send friend requests to each other, and where users can see their and others' list of friends and requested friends. The `relationship` field for each user in the list will represent the current active user's relationship to that user. We may model 1 paginated operation and 1 mutation in this scenario. For the friends list, we may utilize a paginated operation, and sending a friend request could be modeled as a mutation.

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
      after page: Page<Int, [User]>,
      using paging: Paging<Int, [User]>,
      in context: OperationContext
    ) -> Int? {
      page.id + 1
    }

    func fetchPage(
      isolation: isolated (any Actor)?,
      using paging: Paging<Int, [User]>,
      in context: OperationContext,
      with continuation: OperationContinuation<[User], any Error>
    ) async throws -> [User] {
      try await fetchFriends(userId: userId, page: paging.pageId)
    }
  }
}

extension User {
  struct SendFriendRequestArguments: Sendable {
    let userId: Int
  }
  
  @MutationRequest
  static func sendFriendRequestMutation(
    arguments: SendFriendRequestArguments
  ) async throws {
    try await sendFriendRequest(userId: arguments.userId)
  }
}
```

The problem here is that when friend request mutation runs successfully, all screens that utilize friends list query are now displaying outdated data as we haven't explicitly updated the state of those screens to indicate that the friend request was sent.

Utilizing both ``OperationClient`` in conjunction with ``OperationPath`` will make managing this state straight forward.

## Marking Friend Requests As Sent

To start, we'll want to define a reusable transformation on the value of the friends list query that transforms the appropriate user relationship inside the pages. When updating the state of the query directly, we'll call this reusable transform method.

```swift
extension Pages<Int, [User]> {
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

When a user sends a friend request to a user, we'll want to update the friends list query of the receiving user. The most basic approach for handling this is to reach into the ``OperationContext`` that's passed to the mutation, and then grab the `OperationClient` from it. From there, we can peak into the ``OperationStore`` for the corresponding friend list operation and update its state.

```swift
@MutationRequest
static func sendFriendRequestMutation(
  arguments: SendFriendRequestArguments
) async throws {
  @Dependency(\.defaultOperationClient) var client
  try await sendFriendRequest(userId: arguments.userId)

  // Friend request sent successfully, now update the friends list.
  let query = User.friendsQuery(userId: arguments.userId)
  let store = client.store(for: query)
  store.withExclusiveAccess { store in
    store.currentValue = store.currentValue.updateRelationship(
      for: arguments.userId,
      to: .friendRequestSent
    )
  }
}
```

This works, however it's considerably likely that we'll have multiple instances of the friends list query that need to display the relationship status between the current user and the receiving user. Unfortunately, taking stores off the `OperationClient` in a loop is quite inefficient, however the library provides better tools for managing this.

## OperationPath and Store Pattern Matching

To get around the aforementioned performance issue, we can utilize an `OperationPath` to pattern match the existing `OperationStore`s inside the `OperationClient`.

``StatefulOperationRequest``, and all protocols that inherit from it such as ``PaginatedRequest`` and ``MutationRequest`` have an optional `path` requirement. When your query type conforms to Hashable, this requirement is automatically implemented as follows.

```swift
extension StatefulOperationRequest where Self: Hashable {
  var path: OperationPath { [self] }
}
```

This implementation, while convenient, does not take advantage of the full power of `OperationPath`. To understand why, we'll need to briefly cover what an `OperationPath` represents.

### OperationPath Basics

At the very least, you can think of an `OperationPath` as an identifier for a query. This identifier is essentially an array of `Hashable` elements that uniquely identify the query. Under the hood, `OperationClient` utilizes a query's path as key into a dictionary of `OperationStore`s. If you're familiar with [Tanstack Query](https://tanstack.com/query/latest/docs/framework/react/guides/query-keys), `OperationPath` is analogous to the `queryKey` property.

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

The real power of splitting the path into an array of multiple components is that you can pattern match the query utilizing a prefix. For instance, you can get access to the `OperationStore`s for all user friend list queries on an `OperationClient` by checking if the path starts with `["user-friends"]`.

```swift
client.stores(
  matching: ["user-friends"],
  of: PaginatedState<[User], Int>.self
)
```

This will return back a collection of `OperationStore<PaginatedState<[User], Int>>` that you can use to access the current state of all friends list queries in our app.

Now that we have a basic understanding of `OperationPath`, we can explore how to use it effectively in our social app.

### Pattern Matching in SendFriendRequestMutation

With a basic understanding of `OperationPath`, it is actually quite simple to update the state for all friends list queries instances in our app when sending a friend request succeeds.

```swift
@MutationRequest
static func sendFriendRequestMutation(
  arguments: SendFriendRequestArguments
) async throws {
  @Dependency(\.defaultOperationClient) var client
  try await sendFriendRequest(userId: arguments.userId)

  // Friend request succeeded, now optimistically update the 
  // state of all friends list queries in the app.
  let stores = client.stores(
    matching: ["user-friends"],
    of: PaginatedState<[User], Int>.self
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
```

Now, any screen in our app that displays a friends list will automatically update to reflect the new user relationship status.

## Optimistic UI Updates

In our above example, we only update all the friends lists after we've successfully managed to send a friend request through our API. However, we can also use a similar technique to apply optimistic UI updates, such that the result of the mutation is immediately visible in the UI, but if it fails then it gets reverted.

```swift
@MutationRequest
static func sendFriendRequestMutation(
  arguments: SendFriendRequestArguments
) async throws {
  // Optimistically update the user relationships, and reset them 
  // to the default state if the mutation fails.
  do {
    updateRelationships(for: arguments.userId, to: .friendRequestSent)
    try await sendFriendRequest(userId: arguments.userId)
  } catch {
    updateRelationships(for: arguments.userId, to: .notFriends)
    throw error
  }
}

private static func updateRelationships(
  to relationship: User.Relationship,
  userId: Int
) {
  @Dependency(\.defaultOperationClient) var client
  let stores = client.stores(
    matching: ["user-friends"],
    of: PaginatedState<[User], Int>.self
  )
  for store in stores {
    store.withExclusiveAccess { store in
      store.currentValue = store.currentValue.updateRelationship(
        for: arguments.userId,
        to: relationship
      )
    }
  }
}
```

## Rerunning Operations

The above examples demonstrate how to directly update the state for operation during a mutation. However, sometimes it's for the best to just refetch the affected operations instead of updating the state directly. For instance, maybe the updated state cannot be determined solely based on the mutation data, and the only the server has the ability to determine the updated state. Regardless of reason, it's quite easy to perform refetching using the same pattern matching technique shown above.

```swift
@MutationRequest
static func sendFriendRequestMutation(
  arguments: SendFriendRequestArguments
) async throws {
  @Dependency(\.defaultOperationClient) var client
  try await sendFriendRequest(userId: arguments.userId)

  // Friend request sent successfully, now refetch all
  // friends lists in the app.
  Task {
    try await withThrowingTaskGroup(of: Void.self) { group in
      for store in client.stores(matching: ["user-friends"]) {
        group.addTask { try await store.fetch() }
      }
    }
  }
}
```

## Conclusion

In this article, you learned how to use the library to manage asynchronous data fetched by your operations. `OperationClient` can hold the `OperationStore` instances for your queries, and you can utilize `OperationPath` to pattern match these stores. In addition to setting the value of an `OperationStore` directly, you also can decide to refetch the data for a query in order to keep it's state as fresh as possible.
