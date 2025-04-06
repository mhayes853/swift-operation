# Library Inspiration and Principles

Learn about what inspired the creation of this library, and it's core design principles.

## Inspirations

This library was mainly inspired by the popular [Tanstack Query](https://tanstack.com/query/latest) library in the JavaScript ecosystem, [Sharing](https://github.com/pointfreeco/swift-sharing), and [SharingGRDB](https://github.com/pointfreeco/sharing-grdb).

## History

Much of my react work has involved tanstack query, which has been a numerous help in making data fetching and asynchronous state management simple. Tanstack query handles the pain of retries, managing loading and error states, handling scenarios where the network drops, and even keeping fetched data consistent between different screens. In general, I’ve found myself having to come up with in-house solutions to all of these problems in swift applications, and this can be quite annoying.

### Sharing and SharingGRDB

Some time ago the wonderful guys at Pointfree isolated their [Sharing](https://github.com/pointfreeco/swift-sharing/tree/main) library from TCA, allowing it to be utilized in vanilla SwiftUI, and even in cross-platform Swift applications on WASM and Linux.

On its own this library provides a few facilities that Tanstack query provides:
- Managing loading and error states.
- Sharing state between different screens.
- Subscribing to updates from different data sources.

Given that its purpose is to be a general library over any kind of shared external data source, it does its job quite well. However, it doesn’t directly provide all the necessary tools for handling asynchronous data from over the network or any kind of data that takes significant time to load. The library does have a case study on how to make a `SharedReaderKey` for data that’s fetched from an API, but that case study is extremely limited.

Some time after Sharing was split into a separate library, the Pointfree guys made an entire video series on GRDB and SQLite which culminated into a new library built on top of Sharing called [SharingGRDB](https://github.com/pointfreeco/sharing-grdb).

By itself, SharingGRDB is an extremely simple library, merely wrapping GRDB’s `ValueObservation` inside of a `SharedReaderKey`. However, it has a very interesting way of defining how data in an `@SharedReader` was fetched from the database. At it’s core, data can be fetched via creating a `FetchKeyRequest` conformance.
```swift
import SharingGRDB

struct Player: Codable, FetchableRecord, MutablePersistableRecord {
  var id: Int64?
  var name: String
}

struct AllPlayersByName: FetchKeyRequest {
  func fetch(_ db: Database) throws -> [Player] {
    try Player.fetchAll(
      db,
      sql: "SELECT * FROM players ORDER BY name DESC",
      arguements: []
    )
  }
}
```
This `AllPlayersByName` request can then be provided to an `@SharedReader`.
```swift
@SharedReader(.fetch(AllPlayersByName())) var players
```

After seeing, this style, my first thought was _“What if we could describe the notion of fetching data asynchronously using protocols, just like how `FetchKeyRequest` defines such a notion from fetching from a SQLite database?”_

That alone gave me leverage to build this library.

## Principles

At its core, this library provides all the functionallity that one can find in Tanstack Query, all ported over to Swift. Yet even Tanstack Query also has many issues around extending the core functionallity that this library addresses.

So in no particular order, here are the primary design principles of this library:
1. **Queries should be easy to create and compose together.**
   1. The former is achieved through making `QueryRequest` only having 1 primary requirement, and the latter through `QueryModifier`.
2. **Different parts of the library should be entirely decoupled from each other.**
   1. For instance, if you just want to use the `QueryRequest` in a headless fashion and not care about the state management provided by `QueryStore`, you can write your own code that just uses `QueryRequest` directly.
   2. You may also not want to use the `QueryClient` for some reason (eg. you want 2 separate store instances for the same query), as such you can create stores directly through `QueryStore.detached`.
   3. You also may not like how some of the built-in query modifiers are implemented, say retries, and thus you could write your own retry `QueryModifier`.
3. **Essential functionallity should be built on top of generic extendable abstractions, and should not just be baked into the library.**
   1. For instance, checking whether the network is down, or if the app is currently focused are built on top of `FetchCondition`. This is unlike Tanstack Query, which bakes the notion of connectivity and application focus state directly into the queries themselves.
   2. Another case would be common query modifiers such as retries. Retries are built on top of the generic `QueryModifier` system, and unlike Tanstack Query is not baked into the query itself.
   3. Even `QueryModifier` is built on top of `QueryRequest`, as under the hood a `ModifiedQuery` is used to represent a query which has a modifier attached to it.
4. **Custom Query Paradigms should be possible.**
   1. The library provides 3 paradigms, the base query paradigm represented by `QueryRequest`, infinite/paginated queries represented by `InfiniteQueryRequest`, and mutations (eg. making a POST to an API) represented by `MutationRequest`.
   2. You should be able to create your own query paradigm for your own purposes. For instance, one could theoretically create a query paradigm for fetching recursive data, and that could be represented via some `RecursiveQueryRequest` protocol.
5. **Custom Query Paradigms should be derived from the base Query Paradigm.**
   1. `MutationRequest` and `InfiniteQueryRequest` are built directly on top of `QueryRequest` itself. This allows all 3 query paradigms to share query logic such as retries. By implementing the retry modifier once, we can reuse it with ordinary queries, paginated infinite queries, and mutations.
   2. Your custom query paradigm should also be implementable on top of `QueryRequest`. This would allow all existing modifiers to work with your query paradigm, as well as being able to manage the state of your query paradigm though a `QueryStore`.
6. **The library should support as many platforms, libraries, frameworks, and app architectures (TCA, MVVM, MV, etc.) as possible.**
   1. Just because you don’t like to put all your logic directly in a SwiftUI `View` doesn’t mean that you shouldn’t be able to use the full power of this library (unlike SwiftData).
   2. I don’t know nor care about your app architecture or what platforms you’re deploying on. Determing that is you, your team's, and your company’s job, not mine. As a result, it’s for the best that I simply give you the tools to integrate the library into your app, and that I don't add any more opinions than that.
