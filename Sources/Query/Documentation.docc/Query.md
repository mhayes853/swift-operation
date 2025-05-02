# ``Query``

A lightweight cross-platform library for fetching and managing asynchronous data in Swift, SwiftUI, Sharing, WASM, Linux, and more.

## Motivation

An essential component of building modern applications stems from fetching and managing asynchronous data located on various remote sources such as REST APIs and more.

Fetching remote data is inherently flakey, therefore it's essential that your code is robust such that when things go wrong your users aren't angry. To solve this, your application may need to track loading states, track error states, perform retries, add exponential backoff, track the user's network connection state, and much more.

Additionally, keeping remote data in your app consistent with the data from a remote source is also incredibly difficult, perhaps more so than fetching the data itself. For instance, if one screen in your app displays a list of friends, and the user unfriends someone on another screen, it would be in your best interest to update active screens that display the full list of friends.

Your app may also display long lists of fetched data that support infinite scrolling. As a result, you'll need to implement a pagination system for the data you're fetching.

All of this can require lots of boilerplate code to manage, and is not code that generally relates directly to the features of your application.

***Swift Query, provides a simple framework to manage this complexity, with the flexibility to adapt to any data fetching needs for your app.***

## Getting Started

The first thing you'll need to do is create a data type and a ``QueryRequest`` for the data you want to fetch.

```swift
import Query

struct Post: Codable, Sendable, Identifiable {
  typealias ID = Int

  let id: ID
  let userId: Int
  let title: String
  let body: String
}

extension Post {
  static func query(for id: ID) -> Query {
    PostQuery(id: id)
  }

  struct Query: QueryRequest, Hashable {
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
}
```

Already, creating a simple data type that conforms to the `QueryRequest` protocol gives you a lot of power. For instance, you can chain on modifiers to add retries, deduplication, and even automatic refetching when the network comes back online.

```swift
let query = Post.query(for: 1)
  .retry(limit: 3)
  .refetchOnChange(of: .connected(to: NWPathMonitorObserver.shared))
  .deduplicated()
```

> Note: You typically don't need to use all of the above modifiers unless you want to override the default behavior. The default initialization of a ``QueryClient`` instance will automatically add these modifiers to your queries.

From here, there are a variety of ways that you can proceed depending on what technologies you're using. The library natively supports observing queries with the following technologies:
- SwiftUI
- [Sharing](https://github.com/pointfreeco/swift-sharing)
- Combine
- Async Sequences
- Pure Swift

### SwiftUI Usage

In SwiftUI, you can easily observe the state of your query inside a view.

```swift
import QuerySwiftUI

struct PostView: View {
  @State.Query<Post.Query> var state: Post.Query.State

  init(id: Int) {
    self._state = State.Query(Post.query(for: id))
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

With [Sharing](https://github.com/pointfreeco/swift-sharing), you can easily observe the state of your query using the `@SharedQuery` property wrapper.

```swift
import SharingQuery

// This will begin fetching the post.
@SharedQuery(Post.query(for: 1)) var post

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

If you're just using pure swift, you can observe queries by using ``Query/QueryStore`` directly.

```swift
// Step 1: Create a QueryClient (You'll share this throughout your app).
let queryClient = QueryClient()

// Step 2: Retrieve the store from the client. (This applies some
// default modifiers to your queries such as retries, deduplication,
// and more.)
let store = queryClient.store(for: Post.query(for: 1))

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
      in context: QueryContext,
      with continuation: QueryContinuation<Void>
    ) async throws {
      // POST to the API to like the post...
    }
  }
}
```

`MutationRequest` inherits from ``QueryRequest``, so you can observe it just like you would a normal query. To invoke your mutation, you'll typically call the `mutate` method that lives in the technology you're integrating with. For instance, in SwiftUI:

```swift
struct LikePostButton: View {
  @State.Query(Post.likeMutation) var state
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
  static func listQuery(for feedId: Int) -> FeedQuery {
    FeedQuery(feedId: feedId)
  }

  struct FeedQuery: InfiniteQueryRequest, Hashable {
    typealias PageID = String
    typealias PageValue = PostsPage

    let feedId: Int

    let initialPageId = "initial"
 
    func pageId(
      after page: InfiniteQueryPage<String, PlayersPage>,
      using paging: InfiniteQueryPaging<String, PlayersPage>,
      in context: QueryContext
    ) -> String? {
      page.value.nextPageToken
    }

    func fetchPage(
      using paging: InfiniteQueryPaging<String, PlayersPage>,
      in context: QueryContext,
      with continuation: QueryContinuation<PlayersPage>
    ) async throws -> PostsPage {
      try await self.fetchFeedPage(for: paging.pageId)
    }
  }
}
```

`InfiniteQueryRequest` inherits from ``QueryRequest``, so you can observe it just like you would a normal query. You can use the `fetchNextPage` and `fetchPreviousPage` to fetch the next and previous pages of the list respectively. In SwiftUI, this could look like:

```swift
struct FeedView: View {
  @State.Query<PostsPage.FeedQuery> var state: PostsPage.FeedQuery.State

  init(id: Int) {
    self._state = State.Query(PostsPage.feedQuery(for: id))
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

## When Not To Use Swift Query

Swift Query is a powerful library for fetching and managing asynchronous data, but it's not suitable for every problem. For these kinds of applications, consider using another library, or even just rolling your own solution.

- Applications with primarily local data stored with SQLite, Core/Swift Data, Realm, etc.
  - For these applications, you'll be better off using the SDKs directly that manage the local data, or if you're using SQLite you may look into [SharingGRDB](https://github.com/pointfreeco/sharing-grdb) instead. Swift Query adds lots of extra noise such as loading states and multistage queries that isn't necessary if all of your data is stored locally on disk, and can be fetched with little delay.
- Applications that primarily stream live data such from sources such as websockets.
  - Swift Query can work well with live data such as websockets via yielding live updates from the query using a ``QueryController``. However, if your data is mostly "streamed" and not really "fetched", then you may be able to skip the noise of Swift Query and utilize [Sharing](https://github.com/pointfreeco/swift-sharing) directly for managing state.
