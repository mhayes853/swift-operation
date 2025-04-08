# ``Query``

A lightweight cross-platform library for fetching and managing asynchronous data in Swift, SwiftUI, Sharing, WASM, Linux, and more.

## Motivation

An essential component of building modern applications stems from fetching and managing asynchronous data located on various remote sources such as REST APIs and more.

Fetching remote data is inherently flakey, so it is imperative that your code is designed well when things go wrong. To solve this, your application may need to perform retries, add exponential backoff, check the user's connection state, and much more.

Additionally, keeping remote data on the client up-to-date with the data from a remote source is also incredibly difficult, perhaps more so than fetching the data itself.

Lastly, user actions that take place on isolated parts of your UI such as submitting a form may cause remote data updates, and ideally your application will automatically update the data on all screens that depend on the newly submitted form data.

All of this can require lots of boilerplate code to manage, and is not code that generally relates directly to the features of your application.

***With Swift Query, you can forget about writing code that has to manage loading, error states like this.***

```swift
import SwiftUI

enum LoadingState<T> {
  case idle
  case loading
  case error(any Error)
  case success(T)
}

struct ContentView: View {
  let userId: Int
  @State private var state = LoadingState<User>.loading

  var body: some View {
    VStack {
      switch state {
      case .loading:
        ProgressView()
      case let .error(error):
        Text("Error: \(error.localizedDescription)")
      case let .success(user):
        UserView(user)
      }
    }
    .task { await fetchUser() }
  }

  private func fetchUser() async {
    do {
      state = .loading
      let (data, _) = try await URLSession.shared.data(
        from: URL(string: "https://example.com/user/\(userId)")!
      )
      let user = try JSONDecoder().decode(User.self, from: data)
      state = .success(user)
    } catch {
      state = .error(error)
    }
  }
}
```

Yet, removing the need to manage loading and error states is just the beginning, Swift Query provides many more tools to prevent you from writing boilerplate data fetching code.

## Getting Started

The first thing you'll need to do is create a data type and a `QueryRequest` for the data you want to fetch.

```swift
import Query

struct Post: Codable, Sendable {
  let id: Int
  let userId: Int
  let title: String
  let body: String
}

struct PostQuery: QueryRequest, Hashable {
  let id: Int

  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Post>
  ) async throws -> Post {
    let url = URL(string: "https://jsonplaceholder.typicode.com/posts/\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(Post.self, from: data)
  }
}
```

Already, creating a simple data type that conforms to the `QueryRequest` protocol gives you a lot of power. For instance, you can chain on modifiers to add retries, deduplication, and even automatic refetching when the network comes back online.

```swift
let query = PostQuery(id: 1)
  .retry(limit: 3)
  .refetchOnChange(of: .connected(to: NWPathMonitorObserver.shared))
  .deduplicated()
```

> Note: You typically don't need to use all of the above modifiers unless you want to override the default behavior. By default, a `QueryClient` instance will automatically add these modifiers to your queries.

Then, you can proceed depending on what libraries, frameworks, or architectural patterns you're using.

### Pure Swift

If you're just using pure swift, you can start fetching data in 3 easy steps.

```swift
// Step 1: Create a QueryClient (You'll share this throughout your app).
let queryClient = QueryClient()

// Step 2: Retrieve the store from the client. (This applies some
// default modifiers to your queries such as retries, deduplication,
// and more.)
let store = queryClient.store(for: PostQuery(id: 1))

// Step 3: Subscribe to the store (by default this will begin fetching the post).
let subscription = store.subscribe(
  with: QueryEventHandler { state, _ in
    print("Post", state.currentValue)
    print("Is Loading", state.isLoading)
    print("Did Error", state.error != nil)
  }
)
```

### SwiftUI

In SwiftUI, you can easily observe the state of your query inside a view. All the same default modifiers as the pure swift example are also applied to your query, as a `QueryClient` instance is used under the hood.

```swift
import Query
import SwiftUI

struct PostView: View {
  @State.Query<PostQuery> var state: PostQuery.State

  init(id: Int) {
    // This will begin fetching the post.
    self._state = State.Query(PostQuery(id: id))
  }

  var body: some View {
    VStack {
      switch state.status {
      case .idle:
        Text("Idle")
      case .loading:
        ProgressView()
      case let .result(.success(post)):
        Text(post.title)
        Text(post.body)
      case let .result(.failure(error)):
        Text(error.localizedDescription)
      }
    }
  }
}
```

### Sharing

With [Sharing](https://github.com/pointfreeco/swift-sharing), you can easily observe the state of your query using the `@Shared` property wrapper. All the same default modifiers as the pure swift example are also applied to your query, as a `QueryClient` instance is used under the hood.

> Note: This functionallity requires you to import the `SharingQuery` product of this package.

```swift
import SharingQuery

// This will begin fetching the post.
@Shared(.query(PostQuery(id: 1))) var post

if $post.isLoading {
  print("Loading")
} else if let error = $post.loadError {
  print("Error", error)
} else {
  print("Post", post)
}
```

You can learn more about using queries with Sharing [here](TODO).

### In a View Model

If you want to observe your query in view model, you can utilize the built-in combine publisher on the `QueryStore`.

```swift
import Combine
import SwiftUI

@MainActor
final class PostViewModel: ObservableObject {
  @Published var post = PostQuery.State(initialValue: nil)

  private var cancellables = Set<AnyCancellable>()

  // ...

  init(id: Int, client: QueryClient) {
    // This will begin fetching the post.
    let store = client.store(for: PostQuery(id: id))
    store
      .publisher
      .sink { [weak self] output in
        self?.post = output.state
      }
      .store(in: &cancellables)
  }

  // ...
}
```

## When Not To Use Swift Query

Swift Query is a powerful library for fetching and managing asynchronous data, but it's not suitable for every problem. For these kinds of applications, consider using another library, or even just rolling your own solution.

- Applications with primarily local data stored with SQLite, Core/Swift Data, Realm, etc.
  - For these applications, you'll be better off using the SDKs directly that manage the local data, or if you're using SQLite you may look into [SharingGRDB](https://github.com/pointfreeco/sharing-grdb) instead. Swift Query adds a lot of extra noise such as loading states and multistage queries that isn't really necessary if all of your data is stored locally on disk, and can be fetched with little delay.
- Applications that primarily stream live data such from sources such as websockets.
  - Swift Query can work well with live data such as websockets via yielding live updates from the query using a `QueryController`. However, if your data is mostly "streamed" and not really "fetched", then you may be able to skip the noise of Swift Query and utilize [Sharing](https://github.com/pointfreeco/swift-sharing) directly for managing state.
