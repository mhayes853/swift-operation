# Utilizing the QueryContext

Learn how to best use the ``QueryContext`` to facilitate dependency injection, customizing query behavior, and much more.

## Overview

The `QueryContext` is a powerful tool utilized by many types in the library. In fact, every ``QueryRequest`` you create gets access to it.

```swift
struct PlayerQuery: QueryRequest, Hashable {
  let id: Int

  func fetch(
    in context: QueryContext,
    using continuation: QueryContinuation<Player>
  ) async throws -> Player {
    // We can use the context in here...
  }
}
```

Inside a query, the `QueryContext` provides many different properties for the current execution context. For instance, you can access the current retry index allowing you to adjust your fetching behavior based on the number of retries.

```swift
struct PlayerQuery: QueryRequest, Hashable {
  let id: Int

  func fetch(
    in context: QueryContext,
    using continuation: QueryContinuation<Player>
  ) async throws -> Player {
    if context.retryIndex > 0 {
      // Fetch considering how many times we've retried...
    } else {
      // Fetch normally...
    }
  }
}
```

Yet the power of `QueryContext` is greater.

## Adding Custom Properties to QueryContext

`QueryContext` behaves a lot like SwiftUI's `EnvironmentValues`, and you can extend it with custom properties in a very similar manner to `EnvironmentValues`.

```swift
import Operation
import SwiftUI

// 🟢 SwiftUI

extension EnvironmentValues {
  var customProperty: String {
    get { self[CustomPropertyKey.self] }
    set { self[CustomPropertyKey.self] = newValue }
  }

  private enum CustomPropertyKey: EnvironmentKey {
    static let defaultValue: String = "hello!"
  }
}

// 🟢 QueryContext

extension QueryContext {
  var customProperty: String {
    get { self[CustomPropertyKey.self] }
    set { self[CustomPropertyKey.self] = newValue }
  }

  private enum CustomPropertyKey: Key {
    static let defaultValue: String = "hello!"
  }
}
```

Now you can access your custom property inside of queries.

```swift
struct PlayerQuery: QueryRequest, Hashable {
  let id: Int

  func fetch(
    in context: QueryContext,
    using continuation: QueryContinuation<Player>
  ) async throws -> Player {
    if context.customProperty == "hello!" {
      // Fetch...
    } else {
      // Fetch Differently...
    }
  }
}
```

As can be seen here, we're able to customize the behavior of `PlayerQuery` based on a custom context property. Utilizing this technique allows you to use the `QueryContext` in a variety of ways, some of which we will talk about later.

The `defaultValue` of a ``QueryContext/Key`` is computed everytime the `QueryContext` instance doesn't have an explicitly overriden value. If you want to lazily run an expensive computation for the default value, or use a shared reference, define your default value with as a `static let` property.

```swift
extension QueryContext {
  var myExpensiveProperty: String {
    get { self[MyExpensiveLazyPropertyKey.self] }
    set { self[MyExpensiveLazyPropertyKey.self] = newValue }
  }

  private enum MyExpensiveLazyPropertyKey: Key {
    static let defaultValue = someExpensiveComputation()
  }
}
```

## Setting Up The Context

The `QueryRequest` protocol has an optional requirement to setup a `QueryContext` in a way that the query likes. This method is ran a single time when a ``QueryStore`` for the query is initialized.

```swift
struct SomeQuery: QueryRequest, Hashable {
  func setup(context: inout QueryContext) {
    context.customProperty = "new value"
  }

  // ...
}
```

When the query runs, the value of `customProperty` will be `"new value"`.

This strategy is used for many query modifiers. For instance, retries do this to setup the context with the maximum number of retries allowed for the query. By setting this value in the context, it's possible to disable retries like so.

```swift
struct NoRetryQuery: QueryRequest, Hashable {
  func setup(context: inout QueryContext) {
    context.maxRetries = 0 // Disable retries for this query.
  }

  // ...
}
```

## Dependency Injection

> Note: If your project uses [swift-dependencies](https://github.com/pointfreeco/swift-dependencies), you should rely on the `@Dependency` property wrapper inside your queries instead of creating custom query context properties for your dependencies. Instead, only create custom query context properties for lightweight data that only your query needs to consume such as pagination cursors for HTTP API endpoints.

While making a query like this is easy.

```swift
struct Post: Sendable {
  // ...
}

extension Post {
  static func query(for id: Int) -> some QueryRequest<Self, Query.State> {
    Query(id: id)
  }

  struct Query: QueryRequest, Hashable {
    let id: Int

    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<Post>
    ) async throws -> Post {
      let url = URL(
        string: "https://jsonplaceholder.typicode.com/posts/\(id)"
      )!
      let (data, _) = try await URLSession.shared.data(url: url)
      return try JSONDecoder().decode(Post.self, from: data)
    }
  }
}
```

Writing reliable and deterministic tests for code that utilizes this query is not as straightforward. Since we utilize `URLSession.shared` here, we are essentially forced to make a real network call that won't return deterministic data every time we try to test code that utilizes this query. Sometimes, this is fine as we may want to test end-to-end flows. Yet often we may want to simulate failures, or return mock data that tests a specific edge case of the code utilizing this query.

A simple start to this would be to make a custom context property that allows us to mock the network behavior in the query. You may think that you can utilize a custom `URLProtocol` for this. While this can work, this can be quite cumbersome as creating a mock `URLProtocol` can be somewhat challenging. Doing this is generally [not recommended](https://forums.swift.org/t/mock-urlprotocol-with-strict-swift-6-concurrency/77135/15) as `URLSession` behaves quite differently based on the `URLProtocol`s provided to it. Instead, we'll introduce a lightweight protocol that wraps one of `URLSession`'s methods, and conform `URLSession` to the protocol. Then, we'll expose a context property that defaults to `URLSession.shared`.

```swift
protocol HTTPDataTransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataTransport {}

extension QueryContext {
  var dataTransport: any HTTPDataTransport {
    get { self[DataTransportKey.self] }
    set { self[DataTransportKey.self] = newValue }
  }

  private enum DataTransportKey: Key {
    static let defaultValue = URLSession.shared
  }
}
```

Then we can make a simple change to `Post.Query` to make it not dependent on the `URLSession` singleton.

```diff
struct Query: QueryRequest, Hashable {
  let id: Int

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Post>
  ) async throws -> Post {
    let url = URL(
      string: "https://jsonplaceholder.typicode.com/posts/\(id)"
    )!
-    let (data, _) = try await URLSession.shared.data(url: url)
+    let (data, _) = try await context.dataTransport.data(url: url)
    return try JSONDecoder().decode(Post.self, from: data)
  }
}
```

If we want to return some mock data for testing purposes, we can now leverage `URLProtocol` with a custom `URLSession` instance in our tests.

```swift
@Test
func returnsPost() async throws {
  let store = QueryStore.detached(
    query: Post.query(for: 1),
    initialValue: nil
  )
  store.context.dataTransport = MockDataTransport()

  let post = try await store.fetch()
  let expectedPost = Post(
    id: 1,
    userId: 1,
    title: "Mock Title",
    body: "This is the body of the mock post."
  )
  #expect(post == expectedPost)
}

struct MockDataTransport: HTTPDataTransport {
  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    let mockJSON = """
    {
      "userId": 1,
      "id": 1,
      "title": "Mock Title",
      "body": "This is the body of the mock post."
    }
    """
    let data = mockJSON.data(using: .utf8)!
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!
    return (data, response)
  }
}
```

### Overriding Time

``QueryStateProtocol/valueLastUpdatedAt`` and ``QueryStateProtocol/errorLastUpdatedAt`` properties on ``QueryStateProtocol`` conformances are computed using the ``QueryClock`` protocol. The clock lives on the context, and can be overridden. Therefore, if you want to ensure a deterministic date calculations for various reasons (time freeze, testing, etc.), you can do the following.

```swift
let store = QueryStore.detached(
  query: Post.query(for: 1),
  initialValue: nil
)
let date = Date(timeIntervalSince1970: 1234567890)
store.context.queryClock = .custom { date }

try await store.fetch()

#expect(store.valueLastUpdatedAt == date)
```

### Overriding Delays

The ``QueryDelayer`` protocol is used to artificially delay queries in the case of retries. By default, query retries utilize [Fibonacci Backoff](https://thuc.space/posts/retry_strategies/#fibonacci-backoff) where the query will be artificially delayed by an increasing amount of time based on the current retry index.

For testing, this delay may be unacceptable, but thankfully you can override the `QueryDelayer` on the context to remove delays.

```swift
let store = QueryStore.detached(
  query: Post.query(for: 1),
  initialValue: nil
)
store.context.queryDelayer = .noDelay

try await store.fetch() // Will incur no retry delays.
```

## Conclusion

In this article, we explored how to utilize the `QueryContext` to customize query behavior, and even use it as a tool for dependency injection within queries. `QueryContext` can be extended with custom properties like the SwiftUI `EnvironmentValues`, and queries even have the opportunity to setup the context before fetching.
