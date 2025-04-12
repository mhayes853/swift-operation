# Defaults Values, Contexts, and Modifiers

Learn how to best configure default values, contexts, and modifiers for your queries.

## Default Query Values

It's quite straightforward to add a default value to a query.

```swift
struct YourQuery: QueryRequest, Hashable {
  // ...
}

let query = YourQuery().defaultValue("i am the default value")
let store = client.store(for: query)

#expect(store.currentValue == "i am the default value")
```

In fact, this will event grant you type safety on the current value.

```swift
let query = YourQuery().defaultValue("i am the default value")
let value: String = client.store(for: query).currentValue // ✅ Compiles
```

## Default QueryContext

The ``QueryClient`` holds onto a default ``QueryContext`` that is used to initialize every store it holds. By overriding this context, you can provide default contexts for your queries.

```swift
let client = QueryClient()
client.defaultContext.maxRetries = 0
```

The above example effectively disables retries for all queries since all future ``QueryStore``'s created by the client will use the default context.

> Note: Mutating the default context like this has no effect on stores that have already been created within the query client. It only affects stores created afterwards.

## Default Query Modifiers

The default `QueryClient` already applies a set of default modifiers for both queries and mutations. Here's a list for both.

**Queries**
- Deduplication
- Retries
- Automatic Fetching
- Refetching when the network comes back online
- Refetching when the app reenters from the background

**Mutations**
- Retries

> Note: By default in testing environments, the `QueryClient` disables retries, backoff, refetching on network reconnection, refetching on the app reentering from the background, and artificial delays for queries and mutations.

You can configure these defaults by utilizing the `storeCreator` parameter in the `QueryClient` initializer.

```swift
let client = QueryClient(
  storeCreator: .default(
    retryLimit: 10,
    networkObserver: MockNetworkObserver()
    // More defaults...
  )
)
```

If you want to apply a custom modifier on all of your queries by default, you can make a conformance to the ``QueryClient/StoreCreator`` protocol. The protocol gives you the entirety of control over how a `QueryClient` constructs a store for a query, giving you the chance to apply whatever modifiers that your query needs.

```swift
struct MyStoreCreator: QueryClient.StoreCreator {
  func store<Query: QueryRequest>(
    for query: Query,
    in context: QueryContext,
    with initialState: Query.State
  ) -> QueryStore<Query.State> {
    if query is any MutationRequest {
      // Modifiers applied only to mutations
      return .detached(
        query: query.retry(limit: 3),
        initialState: initialState,
        initialContext: context
      )
    }
    // Modifiers applied only to queries and infinite queries
    return .detached(
      query: query.retry(limit: 3)
        .enableAutomaticFetching(onlyWhen: .always(true))
        .customModifier()
        .deduplicated(),
      initialState: initialState,
      initialContext: context
    )
  }
}

let client = QueryClient(storeCreator: MyStoreCreator())
```

## Conclusion

In this article, you learned how to apply default values, modfiers, and contexts to your queries.
