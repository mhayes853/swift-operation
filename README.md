# Swift Query

Powerful asynchronous state management for Swift, SwiftUI, Linux, WASM, and more.

## Motivation

An essential component of building modern applications stems from fetching and managing asynchronous data located on various remote sources such as REST APIs and more.

Fetching remote data is inherently flakey, therefore it's essential that your code is robust such that when things go wrong your users aren't angry. To solve this, your application may need to track loading states, track error states, perform retries, add exponential backoff, track the user's network connection state, and much more.

Additionally, keeping remote data in your app consistent with the data from a remote source is also incredibly difficult, perhaps more so than fetching the data itself. For instance, if one screen in your app displays a list of friends, and the user unfriends someone on another screen, it would be in your best interest to update active screens that display the full list of friends.

Your app may also display long lists of fetched data that support infinite scrolling. As a result, you'll need to implement a pagination system for the data you're fetching.

All of this can require lots of boilerplate code to manage, and is not code that generally relates directly to the features of your application.

***Swift Query, provides a simple framework to manage this complexity, with the flexibility to adapt to any data fetching needs for your app.***

## Getting Started

The first thing you'll need to do is create a data type and a `QueryRequest` for the data you want to fetch.

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
  static func query(for id: ID) -> some QueryRequest<Post, Query.State> {
    Query(id: id)
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
extension Post {
  static func query(for id: ID) -> some QueryRequest<Post, Query.State> {
    Query(id: id).retry(limit: 3)
      .refetchOnChange(of: .connected(to: NWPathMonitorObserver.shared))
      .deduplicated()
  }
}
```

> [!NOTE]
> You typically don't need to use all of the above modifiers unless you want to override the default behavior. The default initialization of a `QueryClient` instance will automatically add these modifiers to your queries when you use the library in conjunction with your preferred technology.

From here, there are a variety of ways that you can proceed depending on what technologies you're using. The library natively supports observing queries with the following technologies:
- SwiftUI
- [Sharing](https://github.com/pointfreeco/swift-sharing)
- Combine
- AsyncSequence
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

### Pure Swift Usage

If you're just using pure swift, you can observe queries by using `QueryStore` directly.

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

When your app performs a non-GET request to an API or mutates remote data, use the `MutationRequest` protocol.

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

`MutationRequest` inherits from `QueryRequest`, so you can observe it just like you would a normal query. To invoke your mutation, you'll typically call the `mutate` method that lives in the technology you're integrating with. For instance, in SwiftUI:

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

When you need to paginate remote data, use the `InfiniteQueryRequest` protocol.

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
      in context: QueryContext
    ) -> String? {
      page.value.nextPageToken
    }

    func fetchPage(
      using paging: InfiniteQueryPaging<String, PostsPage>,
      in context: QueryContext,
      with continuation: QueryContinuation<PostsPage>
    ) async throws -> PostsPage {
      try await self.fetchFeedPage(for: paging.pageId)
    }
  }
}
```

`InfiniteQueryRequest` inherits from `QueryRequest`, so you can observe it just like you would a normal query. You can use the `fetchNextPage` and `fetchPreviousPage` to fetch the next and previous pages of the list respectively. In SwiftUI, this could look like:

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

## Documentation and Further Reading

The usage shown above should account for nearly all common cases you encounter. Yet, the library ships with many additional advanced tools that can adapt to the variety of interesting ways of how your app needs to fetch data. The documentation has many articles that cover common advanced data fetching patterns, and how the library integrates with those patterns.

## Examples

TODO

## Inspirations and Design Principles

This library was mainly inspired by the popular [Tanstack Query](https://tanstack.com/query/latest) library in the JavaScript ecosystem, and serves as an equivalent in the Swift ecosystem. Additionally the library seeks to improve on the tools that tanstack query provides, but for Swift applications. Like Tanstack Query, the learning curve of the library is meant to be easy to get started with, and increases in difficultly as you seek its more advanced functionallity.

So in no particular order, here are the primary design principles of this library:
1. **Queries should be easy to create and compose together.**
   1. The former is achieved through making `QueryRequest` only having 1 requirement that requires a manual implementation, and the latter through `QueryModifier`.
2. **The library's components should be as decoupled as possible.**
   1. For instance, if you just want to use the `QueryRequest` in a headless fashion and not care about the state management provided by `QueryStore`, you can write your own code that just uses `QueryRequest` directly.
   2. You may also not want to use the `QueryClient` for some reason (eg. you want 2 separate store instances for the same query), as such you can create stores without a client through `QueryStore.detached`.
   3. You also may not like how some of the built-in query modifiers are implemented, say retries, and thus you could write your own retry modifier.
3. **Essential functionallity should be built on top of generic extendable abstractions, and should not be baked into the library.**
   1. For instance, checking whether the network is down, or if the app is currently focused are built on top of `FetchCondition`. This is unlike Tanstack Query, which bakes the notion of connectivity and application focus state directly into the queries themselves.
   2. Another case would be common query modifiers such as retries. Retries are built on top of the generic `QueryModifier` system, and unlike Tanstack Query retries are not baked into the query itself.
   3. Even `QueryModifier` is built on top of `QueryRequest`, as under the hood a `ModifiedQuery` is used to represent a query which has a modifier attached to it.
4. **The library should adapt to any data fetching paradigmn.**
   1. The library provides 3 data fetching paradigms, the most basic paradigm (ie. Just fetch the data with no strings attached) represented by `QueryRequest`, infinite/paginated queries represented by `InfiniteQueryRequest`, and mutations (eg. making a POST request to an API, or updating remote data) represented by `MutationRequest`.
   2. You should be able to create your own data fetching paradigm for your own purposes. For instance, one could theoretically create a query paradigm for fetching recursive data such as nested comment threads, and that could be represented via some `RecursiveQueryRequest` protocol.
5. **All data fetching paradigms should be derived from the most basic paradigmn.**
   1. `MutationRequest` and `InfiniteQueryRequest` are built directly on top of `QueryRequest` itself. This allows all 3 query paradigms to share query logic such as retries. By implementing the retry modifier once, we can reuse it with ordinary queries, paginated infinite queries, and mutations.
   2. Your custom query paradigm should also be implementable on top of `QueryRequest`. This would allow all existing modifiers to work with your query paradigm, as well as being able to manage the state of your query paradigm though a `QueryStore`.
6. **The library should support as many platforms, libraries, frameworks, and app architectures (TCA, MVVM, MV, etc.) as possible.**
   1. Just because you don’t like to put all your logic directly in a SwiftUI `View` doesn’t mean that you shouldn’t be able to use the full power of the library (unlike SwiftData).
   2. What architectural patterns or platforms you're deploying on have no concern with the library. Determing that is you, your team's, and your company’s job, not mine. As a result, it’s for the best that the library gives you a set of generic tools to integrate the library into your app's architecture.

## When Not To Use Swift Query

Swift Query is a powerful library for fetching and managing asynchronous data, but it's not suitable for every problem. For these kinds of applications, consider using another library, or even just rolling your own solution.

- Applications with primarily local data stored with SQLite, Core/Swift Data, Realm, etc.
  - For these applications, you'll be better off using the SDKs directly that manage the local data, or if you're using SQLite you may look into [SharingGRDB](https://github.com/pointfreeco/sharing-grdb) instead. Swift Query adds lots of extra noise such as loading states and multistage queries that isn't necessary if all of your data is stored locally on disk, and can be fetched with little delay.
- Applications that primarily stream live data such from sources such as websockets.
  - Swift Query can work well with live data such as websockets via yielding live updates from the query using a `QueryController`. However, if your data is mostly "streamed" and not really "fetched", then you may be able to skip the noise of Swift Query and utilize [Sharing](https://github.com/pointfreeco/swift-sharing) directly for managing state.

## Installation

You can add StructuredQueriesTagged to an Xcode project by adding it to your project as a package.

> https://github.com/mhayes853/structured-queries-tagged

If you want to use StructuredQueriesTagged in a [SwiftPM](https://swift.org/package-manager/) project,
it's as simple as adding it to your `Package.swift`:

``` swift
dependencies: [
  .package(url: "https://github.com/mhayes853/swift-query", from: "0.1.0"),
]
```

And then adding the product to any target that needs access to the library:

```swift
.product(name: "Query", package: "swift-query"),

// For Sharing integration.
.product(name: "SharingQuery", package: "swift-query"),

// For SwiftUI integration.
.product(name: "QuerySwiftUI", package: "swift-query"),
```

## License

This library is licensed under an MIT License. See [LICENSE](LICENSE) for details.
