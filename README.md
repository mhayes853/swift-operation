# Swift Operation
[![CI](https://github.com/mhayes853/swift-operation/actions/workflows/ci.yml/badge.svg)](https://github.com/mhayes853/swift-operation/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmhayes853%2Fswift-operation%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mhayes853/swift-operation)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmhayes853%2Fswift-operation%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mhayes853/swift-operation)

Flexible asynchronous operation and state management for SwiftUI, Linux, WASM, and more.

## Motivation
Dealing with asynchronous work that interacts with external or remote resources is inherently flakey, yet most software needs to do it. Dealing with this flakiness in your application poses a number of challenges including: Tracking loading states, tracking error states, performing retries, exponential backoff, deduplicating operations, pagination, keeping state in sync across different screens, and much more.

Swift Operation is a library that takes care of much of that complexity for you, and additionally allows you to configure that complexity on a per-operation basis.

## Overview
First, we need to define a data type to operate on, and we’ll create an operation to fetch that data. We can create an operation that performs a simple data fetch by using the `@QueryRequest` macro.
```swift
import Foundation
import Operation

struct Post: Hashable, Identifiable, Sendable, Codable {
  let id: Int
  var userId: Int
  var title: String
  var body: String
}

extension Post {
  static func query(for id: Int) -> some QueryRequest<Post?, any Error> {
    // The modifiers on the query are applied by default, they are
    // only being shown to demonstrate how to configure operations.
    Self.$query(for: id)
      .retry(limit: 3)
      .deduplicated()
      .rerunOnChange(of: .connected(to: NWPathMonitorObserver.startingShared()))
  }

  @QueryRequest
  private static func query(for id: Int) async throws -> Post? {
    let url = URL(string: "https://dummyjson.com/posts/\(id)")!
    let (data, resp) = try await URLSession.shared.data(from: url)
    if (resp as? HTTPURLResponse)?.statusCode == 404 {
      return nil
    }
    return try JSONDecoder().decode(Post.self, from: data)
  }
}
```

Now, we can track the state of the operation in a SwiftUI view using the `@SharedOperation` property wrapper.
```swift
import SharingOperation
import SwiftUI

struct PostView: View {
  @SharedOperation<QueryState<Post?, any Error>> var post: Post??

  init(id: Int) {
    // By default, this will begin fetching the post.
    self._post = SharedOperation(Post.query(for: id))
  }

  var body: some View {
    Group {
      VStack {
        switch self.$post.status {
        case .result(.success(let post)):
          if let post {
            PostDetailView(post: post)
          } else {
            Text("Post Not Found")
          }
        case .result(.failure(let error)):
          Text("Error: \(error.localizedDescription).")
        case .loading:
          ProgressView()
        default:
          EmptyView()
        }
        Button("Reload") {
          Task { try await self.$post.fetch() }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
```
> [!NOTE]
> The `@SharedOperation` property wrapper and `SharingOperation` target are built on top of the `@Shared` property wrapper from [Sharing](https://github.com/pointfreeco/swift-sharing), the same library that powers the property wrappers found in [SQLiteData](https://github.com/pointfreeco/sqlite-data). This means that you can also use it outside of SwiftUI views such as in `@Observable` models.

### Mutations
Mutations are best suited for operations that create, delete, or update data on remote or external sources they use. A good example of this would be HTTP non-GET requests such as POST, PATCH, PUT, DELETE, etc.

We can create a mutation that creates a post by using the `@MutationRequest` macro. A single mutation is designed to work with multiple sets of arguments, which requires us to specify the contents of the post as the mutation’s `Arguments` type.
```swift
extension Post {
  struct CreateArguments: Codable, Sendable {
    let userId: Int
    let title: String
    let body: String
  }

  @MutationRequest
  static func createMutation(arguments: CreateArguments) async throws -> Post {
    let url = URL(string: "https://dummyjson.com/posts/add")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(arguments)
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(Post.self, from: data)
  }
}
```

Now let’s consume the mutation in a SwiftUI view, which allso utilizes the `@SharedOperation` property wrapper to observe the state of the mutation.
```swift
import SwiftUI
import SharingOperation

struct CreatePostView: View {
  @Environment(\.dismiss) private var dismiss
  let userId: Int
  @State private var title = ""
  @State private var postBody = ""
  @SharedOperation(Post.$createMutation) private var create

  var body: some View {
    Form {
      TextField("Title", text: self.$title)
      TextField("Body", text: self.$postBody)

      Button(self.$create.isLoading ? "Creating..." : "Create") {
        Task {
          let args = Post.CreateArguments(
            userId: self.userId,
            title: self.title,
            body: self.postBody
          )
          try await self.$create.mutate(with: args)
          self.dismiss()
        }
      }
      .disabled(self.$create.isLoading)

      if let error = self.$create.error {
        Text("Error: \(error.localizedDescription)")
      }
    }
    .navigationTitle("Create Post")
  }
}
```

The key difference between queries and mutations is that a single mutation instance can operate on multiple set or arguments, whereas a single query instance can only operate on the set of members it was constructed with. The `@SharedOperation` property wrapper, as well as the `OperationClient` will utilize this difference as we’ll see later.

### Pagination
Paginated operations can be implemented through the `PaginatedRequest` protocol. This time, we'll' create a struct that describes how to fetch a single page of data. In order to know what page needs to be fetched, there’s also a functional requirement that requires us to provide next `PageID` in the list of pages.

Let’s create a paginated operation that provides pages for a feed of posts.
```swift
extension Post {
  struct FeedPage: Codable, Sendable {
    let posts: [Post]
    let total: Int
    let skip: Int
  }
}

extension Post {
  static let feedQuery = FeedQuery()

  struct FeedQuery: PaginatedRequest, Hashable, Sendable {
    private static let limit = 10

    let initialPageId = 0

    func pageId(
      after page: Page<Int, FeedPage>,
      using paging: Paging<Int, FeedPage>,
      in context: OperationContext
    ) -> Int? {
      // Nil means there's no more pages to fetch.
      page.value.skip < page.value.total ? page.id + 1 : nil
    }

    func fetchPage(
      isolation: isolated (any Actor)?,
      using paging: Paging<Int, FeedPage>,
      in context: OperationContext,
      with continuation: OperationContinuation<FeedPage, any Error>
    ) async throws -> FeedPage {
      var url = URL(string: "https://dummyjson.com/posts")!
      url.append(
        queryItems: [
          URLQueryItem(name: "limit", value: "\(Self.limit)"),
          URLQueryItem(
            name: "skip",
            value: "\(paging.pageId * Self.limit)"
          )
        ]
      )
      let (data, _) = try await URLSession.shared.data(from: url)
      return try JSONDecoder().decode(FeedPage.self, from: data)
    }
  }
}
```

Now let’s once again use the `@SharedOperation` property wrapper to created a paginated feed SwiftUI view.
```swift
struct PostsFeedView: View {
  @SharedOperation(Post.feedQuery) private var feed

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 10) {
        ForEach(self.feed) { page in
          ForEach(page.value.posts) { post in
            PostDetailView(post: post)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        if let error = self.$feed.error {
          Text("Error: \(error.localizedDescription)")
        }
        Button(self.$feed.isLoading ? "Loading..." : "Load More") {
          Task { try await self.$feed.fetchNextPage() }
        }
      }
    }
  }
}
```

### Modifiers
Operations can be customized declaratively by using the `OperationModifier` protocol. The library uses this protocol to add default behaviors to your operations such as retries and deduplication.

We can conform to the protocol create a modifier that adds artificial delay to an operation. Such a modifier could be useful for SwiftUI previews where you may want to apply such a delay to simulate a long loading state.
```swift
import Operation

extension OperationRequest {
  func delay(for duration: OperationDuration) -> ModifiedOperation<Self, DelayModifer<Self>> {
    self.modifier(DelayModifer(duration: duration))
  }
}

struct DelayModifer<Operation: OperationRequest>: OperationModifier, Sendable {
  let duration: OperationDuration

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    try? await context.operationDelayer.delay(for: self.duration)
    return try await operation.run(isolation: isolation, in: context, with: continuation)
  }
}

@QueryRequest
func someQuery() {
  // ...
}

@MutationRequest
func someMutation() {
  // ...
}

let delayedQuery = $someQuery.delay(for: .seconds(1))
let delayedMutation = $someMutation.delay(for: .seconds(1))
```

The modifier works regardless of the operation type because all operation types inherit from the `OperationRequest` protocol, which itself can apply modifiers.

### Multiple Data Updates
You can use the `OperationContinuation` instance passed to your operation to yield multiple data updates before returning. For example, you may want to temporarily yield cached data from disk while fetching the real live data from your server.
```swift
extension Post {
  @QueryRequest
  static func cachedQuery(
    id: Int,
    continuation: OperationContinuation<Post?, any Error>
  ) async throws -> Post? {
    async let post = Self.fetchPost(for: id)
    if let cached = try PostCache.shared.post(for: id) {
      continuation.yield(cached)
    }
    return try await post
  }

  // ...
}
```
> [!NOTE]
> To learn more about multiple data updates, checkout [MultistageOperations](https://swiftpackageindex.com/mhayes853/swift-operation/main/documentation/operationcore/multistageoperations). Additionally, you can also find usage examples such as [file downloads](https://github.com/mhayes853/swift-operation/blob/main/Examples/CaseStudies/CaseStudies/02-Downloads.swift) and [FoundationModels streaming](https://github.com/mhayes853/swift-operation/blob/main/Examples/CanIClimb/CanIClimbKit/Sources/CanIClimbKit/MountainsCore/ClimbReadiness/Mountain%2BClimbReadinessGeneration.swift) in the demos.

### Sharing State
Using different instances of the `@SharedOperation` property wrapper with the same operation will efficiently share the state of the operation across both usages. In the following example, both `ParentView` and `ChildView` will observe state from the fetch of the post, that is the post will only be fetched a single time despite 2 instances of the property wrapper being in-memory.
```swift
import SharingOperation
import SwiftUI

// ParentView and ChildView observe the same post operation.
// Therefore the post is only fetched a single time.

struct ParentView: View {
  @SharedOperation(Post.query(for: 10)) private var post

  var body: some View {
    ChildView()
  }
}

struct ChildView: View {
  @SharedOperation(Post.query(for: 10)) private var post

  var body: some View {
    // ...
  }
}
```

The reason this works is because `@SharedOperation` uses the same `OperationStore` instance under the hood for both instances in `ParentView` and `ChildView`.

`OperationStore` is the runtime of an operation, and invokes your operation whilst managing its state directly. It has a `OperationStore.subscribe` method that `@SharedOperation` wraps such that you can observe the state in SwiftUI views and more.

`@SharedOperation` is able to use the same store instance under the hood due to the `OperationClient` class. `OperationClient` is a class that manages all `OperationStore` instances in your application. You can access the client through the `@Dependency(\.defaultOperationClient)` property wrapper from [swift-dependencies](https://github.com/pointfreeco/swift-dependencies/tree/main).
```swift
import SharingOperation

@MutationRequest
func sendFriendRequestMutation(
  arguments: SendFriendRequestArguments
) async throws {
  @Dependency(\.defaultOperationClient) var client
  try await sendFriendRequest(userId: arguments.userId)

  // Friend request succeeded, now optimistically update the state
  // of all friends list queries in the app.
  let stores = client.stores(
    matching: ["user-friends"],
    of: PaginatedState<[User], Int>.self
  )
  for store in stores {
    store.withExclusiveAccess { store in
      store.currentValue = store.currentValue.updateRelationship(
        for: arguments.userId,
        to: .friendRequestSent
      )
    }
  }
}
```
> [!NOTE]
> To learn more about advanced state management practices including pattern matching using the `OperationPath` type, similar to [Tanstack Query’s query key](https://tanstack.com/query/latest/docs/framework/react/guides/query-keys) pattern matching, checkout [PatternMatchingAndStateManagement](https://swiftpackageindex.com/mhayes853/swift-operation/main/documentation/operationcore/patternmatchingandstatemanagement).

## Traits
The library ships with a handful of package traits, which allow you to conditionally compile dependencies and features of the library. You can learn more about package traits from reading the official evolution [proposal](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md).
- `SwiftOperationLogging` - Adds swift-log support to the library, including a `Logger` context property and the `logDuration` modifier.
- `SwiftOperationWebBrowser` - Integrates web browser APIs with the library using JavaScriptKit. (Only enable for WASM Browser Applications).
- `SwiftOperationNavigation` - Integrates SwiftNavigation's `UITransaction` with `@SharedOperation`.
- `SwiftOperationUIKitNavigation` - Integrates UIKitNavigation's `UIKitAnimation` with `@SharedOperation`.
- `SwiftOperationAppKitNavigation` - Integrates AppKitNavigation's `AppKitAnimation` with `@SharedOperation`.

## Documentation
The documentation for releases and main are available here.
* [main](https://swiftpackageindex.com/mhayes853/swift-operation/main/documentation/operationcore/)
* [0.x.x](https://swiftpackageindex.com/mhayes853/swift-operation/~/documentation/operationcore/)

#### SharingOperation
* [main](https://swiftpackageindex.com/mhayes853/swift-operation/main/documentation/sharingoperation/)
* [0.x.x](https://swiftpackageindex.com/mhayes853/swift-operation/~/documentation/sharingoperation/)

## Demos
There are multiple demos available in the repo to see the library in action across a variety of different scenarios and platforms.
- [**CanIClimb**](https://github.com/mhayes853/swift-operation/tree/main/Examples/CanIClimb)
  - A moderately complex application that integrates with an HTTP API to determine whether or not you are able to climb a mountain of your choice. It implements offline support, authentication, robust testing, FoundationModels, and more.
- [**WASM Demo**](https://github.com/mhayes853/swift-operation/tree/main/Examples/WASMDemo)
  - A simple app that shows how to use the library in browser applications with WASM and JavaScriptKit.
- [**Case Studies**](https://github.com/mhayes853/swift-operation/tree/main/Examples/CaseStudies/CaseStudies)
  - An app showcasing numerous common scenarios, and how to adapt the library in those scenarios. It starts from the basics of the library, and progresses to showcase advanced concepts like custom run specifications, completely offline operations, debouncing, downloads, and much more.
- [**Posts**](https://github.com/mhayes853/swift-operation/tree/main/Examples/Posts)
  - Demos from this README.

## Inspirations and Directions
This library was heavily inspired by [Tanstack Query](https://tanstack.com/query/latest/docs/framework/react/examples/basic) from the JavaScript ecosystem, as well as [SQLiteData](https://github.com/pointfreeco/sqlite-data), and [Effect](https://effect.website/) (a TypeScript library).

The original aim of the library was just to bring a powerful asynchronous state manager like Tanstack Query and SQLiteData over to Swift for general async operations. However, the possibilities of the library can be expanded to make writing and building around asynchronous operations as a whole a lot easier in the same way Effect is doing over in TypeScript. This second point is more pronounced through stateless operations that use the `OperationRequest` protocol directly.

Asynchronous state management around operations is a subset of asynchronous operation management. While state management generally means tracking loading, error, and success states, operation management refers to adding behaviors to operations such as retries and deduplication from small and composable parts. The library aims to move further in this direction over time.

## Installation
You can add Swift Operation to an Xcode project by adding it to your project as a package. Make sure to add the `SharingOperation` target to your package to get access to the `@SharedOperation` property wrapper.
> https://github.com/mhayes853/swift-operation

> ⚠️ At of the time of writing this, Xcode 26 does not seem to include a UI for enabling traits on swift packages through the Files > Add Package Dependencies menu. If you want to enable traits, you will have to install the library inside a local swift package that lives outside your Xcode project.

If you want to use Swift Operation in a [SwiftPM](https://swift.org/package-manager/) project, it's as simple as adding it to your `Package.swift`.
``` swift
dependencies: [
  .package(
    url: "https://github.com/mhayes853/swift-operation",
    from: "0.3.0",
    // To enable any traits.
    traits: ["SwiftOperationLogging"]
  ),
]
```

And then adding the product to any target that needs access to the library.
```swift
.product(name: "Operation", package: "swift-operation"),

// For the @SharedOperation property wrapper.
.product(name: "SharingOperation", package: "swift-operation"),
```

## License
This library is licensed under an MIT License. See [LICENSE](https://github.com/mhayes853/swift-operation/blob/main/LICENSE) for details.
