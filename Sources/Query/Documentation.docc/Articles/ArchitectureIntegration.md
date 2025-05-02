# Integration with your App's Architecture

Learn how to integrate the library with your app's architecture whether you're using MVVM, TCA, Clean Architecture, or even just keeping it simple with plain SwiftUI views.

## Overview

One of the library's guiding design principles is to not care about what architecture or platforms you're building with. For all intensive purposes, those details should be left to your specific project, and the library should be usable regardless of how you do things.

We'll take a look at how to integrate the library into both architectures with few abstraction layers like MV, and architectures that tend to use more layers like the Clean Architecture.

## The MV Pattern

The MV (Model-View) pattern at its core isn't entirely well defined, but a commonality between all definitions is that it heavily relies on utilizing SwiftUI's property wrappers. A general philosophy is the struct that implements the `View` protocol is considered the model, and SwiftUI handles the view part for you.

That being said, integrating the library into an MV architecture is quite straightforward.

```swift
import SwiftUI
import Query

struct MyView: View {
  @State.Query(SomeData.query) var state

  var body: some View {
    VStack {
      switch state.status {
      case .idle:
        Text("Idle")
      case .loading:
        ProgressView()
      case let .result(.success(data)):
        Text(data)
      case let .result(.failure(error)):
        Text(error.localizedDescription)
      }
    }
  }
}
```

Under the hood, ``SwiftUICore/State/Query`` utilizes a ``QueryClient`` instance in the SwiftUI environment. You can access and override this environment value.

```swift
struct MyView: View {
  @Environment(\.queryClient) var client

  // ...
}
```

The `QueryClient` in the environment is shared by all `@State.Query` instances, so doing things like this will share the query state between different views.

```swift
import SwiftUI
import Query

struct ParentView: View {
  @State.Query(SomeData.query) var state

  var body: some View {
    VStack {
      // ...
      ChildView()
    }
  }
}

struct ChildView: View {
  @State.Query(SomeData.query) var state

  var body: some View {
    // ...
  }
}
```

In this example, the query state between the parent and child views is shared. Under the hood, this will create 2 separate subscriptions to the underlying ``QueryStore`` at the same time, and thus initially spawn 2 active ``QueryTask`` instances on the state. However, query fetches are deduplicated by default, so this will result in only 1 actual fetch being performed.

## MVVM

Integrating the library into MVVM is also quite straightforward. You can utilize Combine, an AsyncSequence, or even just a plain subscription to a query store inside your view model to observe the query state.

```swift
import Query
import Observation

@MainActor
@Observable
final class MyViewModel {
  var state = SomeData.Query.State(initialValue: nil)
  @ObservationIgnored private var subscriptions = Set<QuerySubscription>()

  init(client: QueryClient) {
    let store = client.store(for: SomeData.query)
    store.subscribe(
      with: QueryEventHandler { [weak self] state, _ in
        Task { @MainActor in
          self?.state = result
        }
      }
    )
    .store(in: &subscriptions)
  }
}
```

## Clean Architecture

The Clean Architecture tends to have more layers of abstraction, and tries to focus on creating a more "pure" domain above all else. Given this set of layers, it's best to treat this library as an implementation detail rather than as part of your core domain. At it's core, the library provides some data fetching utilities combined with a powerful asynchronous state management system. Generally, this state management system is geared towards UI state, so if we look at general Clean Architecture layers:

```
Clean Architecture Layers:

View     ->     View Model     ->     Use Case     ->     Domain
---swift-query operates here---
```

The library would operate in the view or view model layers depending on your use case. Any `QueryRequest` types you make can simply wrap a call to your repository or use case. You can even use the ``QueryContext`` to inject your use case into the query such that a mock can be provided in tests.

```swift
import Query

protocol LoadUserUseCase: Sendable {
  func execute(id: UserID) async throws -> User
}

struct LoadUserUseCaseImpl: LoadUserUseCase {
  func execute(id: UserID) async throws -> User {
    // ...
  }
}

extension QueryContext {
  var loadUserUseCase: any LoadUserUseCase {
    get { self[LoadUserUseCaseKey.self] }
    set { self[LoadUserUseCaseKey.self] = newValue }
  }

  private enum LoadUserUseCaseKey: Key {
    static var defaultValue: any LoadUserUseCase {
      LoadUserUseCaseImpl()
    }
  }
}

extension User {
  static func query(for id: UserID) -> some QueryRequest<Self, Query.State> {
    Query(id: id)
  }

  struct Query: QueryRequest {
    let id: UserID

    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<User>
    ) async throws -> User {
      let user = try await context.loadUserUseCase.execute(id: id)

      guard let client = context.queryClient else { return user }
      // Update the state of any queries here using the QueryClient...
      return user
    }
  }
}
```

Now, you can observe the query in your view model or view like in the examples in the above MVVM and MV sections.

## TCA and Sharing

If you're using TCA, then you can simply import `SharingQuery` and use the `@Shared` property wrapper to observe the state.

```swift
import ComposableArchitecture
import SharingQuery

@Reducer
struct MyReducer {
  @ObservableState
  struct State: Equatable {
    @ObservationStateIgnored
    @SharedQuery(SomeData.query) var value
  }

  // ...
}
```

> Note: By default, any declaration of `@SharedQuery(_)` will add a subscription directly to the underlying `QueryStore` instead of using the cached subscription from Sharing. This allows you to check the total number of components that observe your query.

You can also access and override the underlying `QueryClient` used by the `QueryKey` by overriding the `queryClient` dependency.

```swift
@Reducer
struct MyReducer {
  // ...

  @Dependency(\.queryClient) var client

  // ...
}
```

## Conclusion

In this article, you learned the basics of how to integrate the library into some common architectural patterns. The library takes the stance that you know your application architecture better than itself, and therefore it merely gives you tools to integrate it into your architecture.
