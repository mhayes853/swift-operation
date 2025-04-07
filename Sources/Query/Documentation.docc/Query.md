# ``Query``

A lightweight cross-platform library for fetching and managing asynchronous data in Swift, SwiftUI, Sharing, WASM, Linux, and more.

## Motivation

TODO

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

  func fetch(in context: QueryContext, with continuation: QueryContinuation<Post>) async throws -> Post {
    let url = URL(string: "https://jsonplaceholder.typicode.com/posts/\(id)")!
    let (data, _) = try await URLSession.shared.data(url: url)
    return try JSONDecoder().decode(Post.self, from: data)
  }
}
```

Then, you can proceed depending on what libraries, frameworks, or architectural patterns you're using.

### Pure Swift

If you're just using pure swift, you can start fetching data in 3 easy steps.

```swift
// Step 1: Create a QueryClient (You'll share this throughout your app).
let queryClient = QueryClient()

// Step 2: Retrieve the store from the client.
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

In SwiftUI, you can easily observe the state of your query inside a view.

```swift
import Query
import SwiftUI

struct PostView: View {
  @State.Query var state: PostQuery.State

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

With [Sharing](https://github.com/pointfreeco/swift-sharing), you can easily observe the state of your query using the `@Shared` property wrapper.

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
  - For these applications, you'll be better off using the SDKs directly that manage the local data, or if you're using SQLite you may look into [SharingGRDB](https://github.com/pointfreeco/sharing-grdb) instead. Swift Query adds a lot of extra noise such as loading states and multistage queries that isn't really necessary if all of your data is stored locally on disk, and can be fetched incredibly quickly.
- Applications that primarily stream data such as websockets.
  - Swift Query can work well with live data such as websockets via yielding live updates from the query using a `QueryController`. However, if you're data is mostly "streamed" and not really "fetched", then you may be able to skip the noise of Swift Query and utilize [Sharing](https://github.com/pointfreeco/swift-sharing) directly for managing state.

## Topics

TODO

### Essentials

TODO

### Articles

TODO
