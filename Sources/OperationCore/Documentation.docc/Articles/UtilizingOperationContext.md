# Utilizing the OperationContext

Learn how to best use the ``OperationContext`` to facilitate dependency injection, customizing operation behavior, and much more.

## Overview

The `OperationContext` is a powerful tool used by many types in the library, and is accessible from within an operation. You can use the context as configuration, or even as a way to inject dependencies into your operations.

At it's core, the context is a flexible, strongly typed, and extendable key-value store. This means you can easily add custom properties to it.

Operations and operation modifiers also have the opportunity to setup the context through ``OperationRequest/setup(context:)-9fupm`` and ``OperationModifier/setup(context:using:)-40ul6`` respectively.

Let's now take a look at how you can utilize all of these powers.

## Adding Custom Properties to OperationContext

`OperationContext` behaves a lot like SwiftUI's `EnvironmentValues`, and you can extend it with custom properties in a very similar manner to `EnvironmentValues`.

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

// 🟢 OperationContext

extension OperationContext {
  var customProperty: String {
    get { self[CustomPropertyKey.self] }
    set { self[CustomPropertyKey.self] = newValue }
  }

  private enum CustomPropertyKey: Key {
    static let defaultValue: String = "hello!"
  }
}
```

Now you can access your custom property inside of operations.

```swift
struct PlayerQuery: QueryRequest, Hashable {
  let id: Int

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using continuation: OperationContinuation<Player, any Error>
  ) async throws -> Player {
    if context.customProperty == "hello!" {
      // Fetch...
    } else {
      // Fetch Differently...
    }
  }
}
```

As can be seen here, we're able to customize the behavior of `PlayerQuery` based on a custom context property. Utilizing this technique allows you to use the `OperationContext` in a variety of ways, some of which we will talk about later.

The `defaultValue` of a ``OperationContext/Key`` is computed everytime the `OperationContext` instance doesn't have an explicitly overriden value. If you want to lazily run an expensive computation for the default value, or use a shared reference, define your default value with a `static let` property.

```swift
extension OperationContext {
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

The `OperationRequest` protocol has an optional requirement to setup a `OperationContext` in a way that the operation likes. This method is ran a single time when a ``OperationStore`` for the operation is initialized.

```swift
struct SomeQuery: QueryRequest, Hashable {
  func setup(context: inout OperationContext) {
    context.customProperty = "new value"
  }

  // ...
}
```

When the query runs, the value of `customProperty` will be `"new value"`.

This strategy is used for many operation modifiers. For instance, retries do this to setup the context with the maximum number of retries allowed for the operation. By setting this value in the context, it's possible to disable retries like so.

```swift
struct NoRetryQuery: QueryRequest, Hashable {
  func setup(context: inout OperationContext) {
    context.maxRetries = 0 // Disable retries for this query.
  }

  // ...
}
```

## Dependency Injection

> Note: If your project uses [swift-dependencies](https://github.com/pointfreeco/swift-dependencies), you can also rely on the `@Dependency` property wrapper inside your operations in addition to custom context properties for dependency injection. In this case, custom context properties are more useful for lightweight data that only your operation needs to consume such as pagination cursors for HTTP API endpoints.

While making a query like this is easy.

```swift
struct Post: Sendable {
  // ...
}

extension Post {
  static func query(for id: Int) -> some QueryRequest<Self, any Error> {
    Query(id: id)
  }

  struct Query: QueryRequest, Hashable {
    let id: Int

    func fetch(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      with continuation: OperationContinuation<Post, any Error>
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

extension OperationContext {
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
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Post, any Error>
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
  let store = OperationStore.detached(
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

Now we no longer depend on a live networking service in our test suite, which allows us to write reliable and deterministic tests. However, this example can be taken further by adding a dedicated network layer to your app, see <doc:NetworkLayer> for more.

### Overriding Time

``OperationState/valueLastUpdatedAt`` and ``OperationState/errorLastUpdatedAt`` properties on ``OperationState`` conformances are computed using the ``OperationClock`` protocol. The clock lives on the context, and can be overridden. Therefore, if you want to ensure a deterministic date calculations for various reasons (time freeze, testing, etc.), you can do the following.

```swift
let store = OperationStore.detached(
  query: Post.query(for: 1),
  initialValue: nil
)
let date = Date(timeIntervalSince1970: 1234567890)
store.context.operationClock = .custom { date }

try await store.fetch()

#expect(store.valueLastUpdatedAt == date)
```

### Overriding Delays

The ``OperationDelayer`` protocol is used to artificially delay queries in the case of retries. By default, operation retries utilize exponential backoff where the operation will be artificially delayed by an increasing amount of time based on the current retry index.

For testing, this delay may be unacceptable, but thankfully you can override the `QueryDelayer` on the context to remove delays.

```swift
let store = OperationStore.detached(
  query: Post.query(for: 1),
  initialValue: nil
)
store.context.operationDelayer = .noDelay

try await store.fetch() // Will incur no retry delays.
```

> Note: The default initializer of ``OperationClient`` will automatically disable delays for you during tests.

## Conclusion

In this article, we explored how to utilize the `OperationContext` to customize operation behavior, and even use it as a tool for dependency injection within operations. `OperationContext` can be extended with custom properties like SwiftUI's `EnvironmentValues`, and operations even have the opportunity to setup the context before running.
