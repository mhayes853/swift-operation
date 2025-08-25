# Integration with your Network Layer

Learn how to best use the library alongside your app's network layer.

## Overview

One of the library's guiding design principles is to not care about what architecture or platforms you're building with. For all intensive purposes, those details should be left to your specific project, and the library should be usable regardless of how you do things.

At it's core, the ``QueryRequest`` protocol works with _any_ async function, and is not inherently tied to network requests. This design gives you the flexibility to use the library no matter how your data is fetched. For simple apps it may very well be fine to fetch data using `URLSession` directly inside ``QueryRequest/fetch(in:with:)``, but for a larger more complicated application you'll almost certainly want a sophisticated network layer that encapsulates the details of how data is fetched.

***Swift Operation is designed to enhance your app's network logic regardless if it's represented by a sophisticated network layer or not.***

## With and Without a Dedicated Network Layer

The library does not discriminate between these 2 use cases.

**Without a Dedicated Network Layer**
```swift
import Operation
import Foundation

struct User: Codable {
  let id: Int
  // ...
}

extension User {
  static func query(for id: Int) -> some QueryRequest<Self, Query.State> {
    Query(id: id)
  }

  struct Query: QueryRequest, Hashable {
    let id: Int

    func fetch(
      in context: OperationContext,
      with continuation: OperationContinuation<User>
    ) async throws -> User {
      let url = URL(string: "https://api.myapp.com/user/\(self.id)")!
      let (data, _) = try await URLSession.shared.data(from: url)
      return try JSONDecoder().decode(User.self, from: data)
    }
  }
}
```

**With a Dedicated Network Layer**
```swift
import Operation
import Foundation

struct User: Codable {
  let id: Int
  // ...
}

extension User {
  static func query(for id: Int) -> some QueryRequest<Self, Query.State> {
    Query(id: id)
  }

  struct Query: QueryRequest, Hashable {
    let id: Int

    func fetch(
      in context: OperationContext,
      with continuation: OperationContinuation<User>
    ) async throws -> User {
      try await context.myAppAPI.fetchUser(with: self.id)
    }
  }
}

extension OperationContext {
  var myAppAPI: MyAppAPI {
    get { self[MyAppAPIKey.self] }
    set { self[MyAppAPIKey.self] = newValue }
  }

  private enum MyAppAPIKey: Key {
    static let defaultValue = MyAppAPI.productionInstance
  }
}

final class MyAppAPI: Sendable {
  static let productionInstance = MyAppAPI(
    transport: URLSession.shared,
    baseURL: URL(string: "https://api.myapp.com")!
  )

  static let stagingInstance = MyAppAPI(
    transport: URLSession.shared,
    baseURL: URL(string: "https://api.staging.myapp.com")!
  )

  private let transport: any HTTPDataTransport
  private let baseURL: URL

  init(transport: any HTTPDataTransport, baseURL: URL) {
    self.transport = transport
    self.baseURL = baseURL
  }

  func fetchUser(with id: Int) async throws -> User {
    let url = self.baseURL.appending(path: "user/\(id)")
    let (data, _) = try await self.transport.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
  }
}

protocol HTTPDataTransport: Sendable {
  func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataTransport {}
```

The latter example with a dedicated network layer is more robust, and will generally scale better in larger applications. We can instantiate `MyAppAPI` in a manner that allows us to point to different server environments such as staging and production by passing the appropriate `baseURL` into the initializer. We can also create a mock implementation of the `HTTPDataTransport` protocol that allows us to respond with mock data in test environments. Lastly, we can choose to inject a custom instance of `MyAppAPI` into the query via a custom ``OperationContext`` property, and by default we'll choose to use the production instance. However, this is significantly more lines of code than the example without a dedicated network layer due to the added affordances that allow us to customize the behavior of the app's networking logic.

On the flipside, the former example without a dedicated network layer does not offer any affordances to customize its behavior. It will always fetch from the hardcoded URL using `URLSession.shared`. As such, it's not possible to change the server environment, or mock certain types of responses for testing. However, it's significantly less lines of code due to not having the indirection present in a dedicated networking layer.

Regardless of your architectural choices, Swift Operation will function the exact same in both scenarios. Retries, backoff strategies, automatic refetching, and state management all function the same due to the library's decision to abstract over a general async function opposed to a dedicated networking service.

## Conclusion

In this article, you learned how the library can fit into your app's networking logic. Whether or not you decide to create a sophisticated networking layer is up to how you want to architect your application. Swift Operation will work the same regardless of your choice due to the library's focus on abstracting a general async function rather than abstracting over the network itself.
