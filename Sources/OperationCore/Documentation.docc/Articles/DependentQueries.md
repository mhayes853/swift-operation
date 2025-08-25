# Dependent Queries

Learn how to write queries that depend on the results of other queries.

## Overview

A common use case is to have a query dependent on the data from another query. For instance, your query may need the current user, or the ID of some other entity. There are multiple strategies for dealing with such dependencies, and you'll want to pick the one that's best for your use case.

Each example will depend on a query that represents fetching the current user.

```swift
struct User: Sendable {
  let id: UUID
  // Other fields...
}

extension User {
  static let currentQuery = CurrentQuery()

  struct CurrentQuery: QueryRequest {
    // ...
  }
}
```

## Direct Invocation

Our query to get the user's projects is dependent on the result of the current user query. As such, we can invoke the user query directly inside our user projects query if it no user is present. We can do this by accessing the ``QueryStore`` for the current user query from the ``QueryClient`` and ``QueryContext`` handed to the projects query.

```swift
struct Project: Sendable {
  let id: UUID
  // Other fields...
}

extension Project {
  static let userProjectsQuery = UserProjectsQuery()

  struct UserProjectsQuery: QueryRequest {
    var path: QueryPath {
      ["user-projects"]
    }

    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<[Project]>
    ) async throws -> [Project] {
      guard let client = context.queryClient else { return [] }
      let store = client.store(for: User.currentQuery)
      var user: User
      if let u = store.currentValue {
        user = u
      } else {
        user = try await store.fetch()
      }
      return try await self.fetchProjects(for: user.id)
    }

    private func fetchProjects(for userId: UUID) async throws -> [Project] {
      // ...
    }
  }
}
```

If such a case is common in your application, you may want to extract a helper for ensuring the current user.

```swift
extension QueryContext {
  func ensureCurrentUser() async throws -> User {
    guard let client = queryClient else { throw NoClientError() }
    let store = client.store(for: User.currentQuery)
    if let user = store.currentValue {
      return user
    } else {
      return try await store.fetch()
    }
  }

  private struct NoClientError: Error {}
}
```

```diff
extension Project {
  static let userProjectsQuery = UserProjectsQuery()

  struct UserProjectsQuery: QueryRequest {
    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<[Project]>
    ) async throws -> [Project] {
-      guard let client = context.queryClient else { return [] }
-      let store = client.store(for: User.currentQuery)
-      var user: User
-      if let u = store.currentValue {
-        user = u
-      } else {
-        user = try await store.fetch()
-      }
+      let user = try await context.ensureCurrentUser()
      return try await self.fetchProjects(for: user.id)
    }

    private func fetchProjects(for userId: UUID) async throws -> [Project] {
      // ...
    }
  }
}
```

However, the disadvantage of the direct invocation method in this case is that you wouldn't be able to use the current user data in the query's ``QueryPath``. This can be a limitation when it comes to state management, as you wouldn't be able to distinguish between different user project queries with a `QueryPath`. See <doc:PatternMatchingAndStateManagement> for more on how to manage state.

## Delayed Construction

Another approach to dependent queries is to delay their construction until you have the data from prior queries. The implementation of this is largely dependent on how you integrate the library into your application, but this is what it would look like if your used `SharingQuery`.

```swift
import SharingOperation
import Observation

extension Project {
  static func userProjectsQuery(
    for userId: UUID
  ) -> some QueryRequest<[Self], UserProjectsQuery.State> {
    UserProjectsQuery(userId: userId)
  }

  struct UserProjectsQuery: QueryRequest {
    let userId: UUID

    var path: QueryPath {
      ["user-projects", self.userId]
    }

    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<[Project]>
    ) async throws -> [Project] {
      // ...
    }
  }
}

@MainActor
@Observable
final class UserProjectsModel {
  @ObservationIgnored
  @SharedQuery(User.currentQuery) var user

  @ObservationIgnored
  @SharedQuery<Project.UserProjectsQuery.State> var projects

  func appeared() async {
    let user = try await $user.fetch()
    self._projects = SharedQuery(wrappedValue: nil, Project.userProjectsQuery(for: user.id))
  }
}
```

Here, we regain the ability to have the `userId` in the `QueryPath` of the projects query, at the cost of ergonomics around how the query is constructed. This way, we allow for distinct user project queries to be represented by a `QueryPath`.

## Query Merging

The last strategy is to merge the current user fetching and user projects fetching into a singular query, and delete the existing current user query. This method is best if the current user is only needed for the projects query, and nothing else.

```swift
extension Project {
  static let userProjectsQuery = UserProjectsQuery()

  struct UserProjectsQuery: QueryRequest {
    var path: QueryPath {
      ["user-projects"]
    }

    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<[Project]>
    ) async throws -> [Project] {
      let user = try await self.fetchCurrentUser()
      return try await self.fetchProjects(for: user.id)
    }

    private func fetchCurrentUser() async throws -> User {
      // ...
    }

    private func fetchProjects(for userId: UUID) async throws -> [Project] {
      // ...
    }
  }
}
```

If you want to emit progress/visual updates from the query after the current user is fetched, you can always do so via the ``QueryContinuation`` handed to the projects query. However, like the Direct Invocation strategy, you will lose the ability to have the `userId` in the `QueryPath` of the projects query, thus limiting the query's state management capabilities.

## Retaining the full QueryPath with Direct Invocation

If you want to retain state management with the above 2 strategies, consider creating an advanced Hashable parameter for your query. This way, you can also distinguish between different user project queries with a `QueryPath`.

```swift
enum UserProjectsKey: Hashable, Sendable {
  case userId(UUID)
  case currentUser

  func fetchUserId(in context: QueryContext) async throws -> UUID {
    switch self {
    case let .userId(id):
      return id
    case .currentUser:
      return try await context.ensureCurrentUser().id
    }
  }
}

extension Project {
  static let userProjectsQuery = UserProjectsQuery(key: .currentUser)

  static func userProjectsQuery(
    for id: UUID
  ) -> some QueryRequest<[Project], UserProjectsQuery.State> {
    UserProjectsQuery(key: .userId(id))
  }

  struct UserProjectsQuery: QueryRequest {
    let key: UserProjectsKey

    var path: QueryPath {
      ["user-projects", self.key]
    }

    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<[Project]>
    ) async throws -> [Project] {
      let id = try await self.key.fetchUserId(in: context)
      return try await self.fetchProjects(for: id)
    }

    private func fetchProjects(for userId: UUID) async throws -> [Project] {
      // ...
    }
  }
}
```

## Conclusion

In this article, we explored 3 different methods of handling dependent queries in your application: Direct Invocation, Delayed Construction, and Query Merging. You should pick the most most convenient and strategy to use in your specific scenario.
