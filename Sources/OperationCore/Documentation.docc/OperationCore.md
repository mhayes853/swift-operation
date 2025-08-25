# ``QueryCore``

A lightweight cross-platform library for fetching and managing asynchronous data in Swift, SwiftUI, Sharing, WASM, Linux, and more.

## Getting Started

The first thing you'll need to do is create a data type and a ``QueryRequest`` for the data you want to fetch.

```swift
import Operation

struct Post: Codable, Sendable, Identifiable {
  typealias ID = Int

  let id: ID
  let userId: Int
  let title: String
  let body: String
}

extension Post {
  static func query(for id: ID) -> some QueryRequest<Post, Query.State> {
    Query(id: id)
  }

  struct Query: QueryRequest, Hashable {
    let id: Int

    func fetch(
      in context: OperationContext,
      with continuation: OperationContinuation<Post>
    ) async throws -> Post {
      let url = URL(string: "https://jsonplaceholder.typicode.com/posts/\(id)")!
      let (data, _) = try await URLSession.shared.data(from: url)
      return try JSONDecoder().decode(Post.self, from: data)
    }
  }
}
```

Already, creating a simple data type that conforms to the `QueryRequest` protocol gives you a lot of power. For instance, you can chain on modifiers to add retries, deduplication, and even automatic refetching when the network comes back online.

```swift
extension Post {
  static func query(for id: ID) -> some QueryRequest<Post, Query.State> {
    Query(id: id).retry(limit: 3)
      .refetchOnChange(of: .connected(to: NWPathMonitorObserver.shared))
      .deduplicated()
  }
}
```

> Note: You typically don't need to use all of the above modifiers unless you want to override the default behavior. The default initialization of a ``OperationClient`` instance will automatically add these modifiers to your queries.

From here, there are a variety of ways that you can proceed depending on what technologies you're using. The library natively supports observing queries with the following technologies:
- SwiftUI
- [Sharing](https://github.com/pointfreeco/swift-sharing)
- Combine
- AsyncSequence
- Pure Swift

### SwiftUI Usage

In SwiftUI, you can easily observe the state of your query inside a view.

```swift
import OperationSwiftUI

struct PostView: View {
  @State.Operation<Post.Query> var state: Post.Query.State

  init(id: Int) {
    self._state = State.Operation(Post.query(for: id))
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

> Note: This functionallity requires you to import the `QuerySwiftUI` product of this package.

### Sharing Usage

With [Sharing](https://github.com/pointfreeco/swift-sharing), you can easily observe the state of your query using the `@SharedOperation` property wrapper.

```swift
import SharingOperation

// This will begin fetching the post.
@SharedOperation(Post.query(for: 1)) var post

if $post.isLoading {
  print("Loading")
} else if let error = $post.error {
  print("Error", error)
} else {
  print("Post", post)
}
```

> Note: This functionallity requires you to import the `SharingQuery` product of this package.

### Pure Swift Usage

If you're just using pure swift, you can observe queries by using ``OperationStore`` directly.

```swift
// Step 1: Create a OperationClient (You'll share this throughout your app).
let OperationClient = OperationClient()

// Step 2: Retrieve the store from the client. (This applies some
// default modifiers to your queries such as retries, deduplication,
// and more.)
let store = OperationClient.store(for: Post.query(for: 1))

// Step 3: Subscribe to the store (by default this will begin fetching the post).
let subscription = store.subscribe(
  with: QueryEventHandler { state, _ in
    print("Post", state.currentValue)
    print("Is Loading", state.isLoading)
    print("Did Error", state.error != nil)
  }
)

// Step 3 (Combine Style): Sink the store publisher (by default this will begin fetching the post).
let cancellable = store.publisher.sink { output in
  print("Post", output.state.currentValue)
  print("Is Loading", output.state.isLoading)
  print("Did Error", output.state.error != nil)
}

// Step 3 (AsyncSequence Style): Iterate the store sequence (by default this will begin fetching the post).
for await output in store.states {
  print("Post", output.state.currentValue)
  print("Is Loading", output.state.isLoading)
  print("Did Error", output.state.error != nil)
}
```

### Updating Data

When your app performs a non-GET request to an API or mutates remote data, use the ``MutationRequest`` protocol.

```swift
extension Post {
  static let likeMutation = LikeMutation()

  struct LikeMutation: MutationRequest, Hashable {
    typealias Value = Void

    func mutate(
      with arguments: Post.ID,
      in context: OperationContext,
      with continuation: OperationContinuation<Void>
    ) async throws {
      // POST to the API to like the post...
    }
  }
}
```

`MutationRequest` inherits from ``QueryRequest``, so you can observe it just like you would a normal query. To invoke your mutation, you'll typically call the `mutate` method that lives in the technology you're integrating with. For instance, in SwiftUI:

```swift
struct LikePostButton: View {
  @State.Operation(Post.likeMutation) var state
  let id: Int

  var body: some View {
    Button {
      Task { try await self.$state.mutate(with: self.id) }
    } label: {
      switch state.status {
      case .idle:
        Text("Like")
      case .loading:
        ProgressView()
      case let .result(.success(post)):
        Text("Liked")
      case let .result(.failure(error)):
        Text(error.localizedDescription)
      }
    }
  }
}
```

### Pagination

When you need to paginate remote data, use the ``InfiniteQueryRequest`` protocol.

```swift
struct PostsPage: Sendable {
  let posts: [Post]
  let nextPageToken: String?
}

extension PostsPage {
  static func listQuery(for feedId: Int) -> some InfiniteQueryRequest<String, PostsPage> {
    FeedQuery(feedId: feedId)
  }

  struct FeedQuery: InfiniteQueryRequest, Hashable {
    typealias PageID = String
    typealias PageValue = PostsPage

    let feedId: Int

    let initialPageId = "initial"

    func pageId(
      after page: InfiniteQueryPage<String, PostsPage>,
      using paging: InfiniteQueryPaging<String, PostsPage>,
      in context: OperationContext
    ) -> String? {
      page.value.nextPageToken
    }

    func fetchPage(
      using paging: InfiniteQueryPaging<String, PostsPage>,
      in context: OperationContext,
      with continuation: OperationContinuation<PostsPage>
    ) async throws -> PostsPage {
      try await self.fetchFeedPage(for: paging.pageId)
    }
  }
}
```

`InfiniteQueryRequest` inherits from ``QueryRequest``, so you can observe it just like you would a normal query. You can use the `fetchNextPage` and `fetchPreviousPage` to fetch the next and previous pages of the list respectively. In SwiftUI, this could look like:

```swift
struct FeedView: View {
  @State.Operation<PostsPage.FeedQuery> var state: PostsPage.FeedQuery.State

  init(id: Int) {
    self._state = State.Operation(PostsPage.feedQuery(for: id))
  }

  var body: some View {
    List(self.state.currentValue) { page in
      ForEach(page.value.posts) { post in
        PostCardView(post: post)
      }

      Button {
        Task { try await self.$state.fetchNextPage() }
      } label: {
        Text("Load Next")
      }
    }
  }
}
```
