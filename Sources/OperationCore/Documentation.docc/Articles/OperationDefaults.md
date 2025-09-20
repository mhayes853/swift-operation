# Defaults Values, Contexts, and Modifiers

Learn how to best configure default values, contexts, and modifiers for your operations.

## Default Operation Values

It's quite straightforward to add a default value to a query, mutation, or paginated request.

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

## Default OperationContext

The ``OperationClient`` holds onto a default ``OperationContext`` that is used to initialize every store it holds. By overriding this context, you can provide default contexts for your operations.

```swift
let client = OperationClient()
client.defaultContext.maxRetries = 0
```

The above example effectively disables retries for all queries since all future ``OperationStore``'s created by the client will use the default context.

> Note: Mutating the default context like this has no effect on stores that have already been created within the client. It only affects stores created afterwards.

## Default Operation Modifiers

The default initializer `OperationClient` already applies a set of default modifiers to an operation when it creates its associated store. Here's a list of those modifiers.

**Mutations**
- Retries
- Exponential Backoff

**All Other Operations**
- Deduplication
- Retries
- Exponential Backoff
- Automatic Running
- Rerunning when the network status flips from offline to online.
- Rerunning when the app reenters from the background.

> Note: By default in testing environments, the default initializer of `OperationClient` disables retries, backoff, refetching on network reconnection, refetching on the app reentering from the background, and artificial delays for queries and mutations.

You can configure these defaults by utilizing the `storeCreator` parameter in the `OperationClient` initializer.

```swift
let client = OperationClient(
  storeCreator: .default(
    retryLimit: 10,
    networkObserver: MockNetworkObserver()
    // More defaults...
  )
)
```

If you want to apply a custom modifier on all of your operations by default, you can make a conformance to the ``OperationClient/StoreCreator`` protocol. The protocol gives you the entirety of control over how a `OperationClient` constructs a store for an operation, giving you the chance to apply whatever modifiers that your operation needs.

```swift
struct MyStoreCreator: OperationClient.StoreCreator {
  func store<Operation: StatefulOperationRequest & Sendable>(
    for operation: Operation,
    in context: OperationContext,
    with initialState: Operation.State
  ) -> OperationStore<Operation.State> {
    if query is any MutationRequest {
      // Modifiers applied only to mutations
      return .detached(
        query: query.retry(limit: 3),
        initialState: initialState,
        initialContext: context
      )
    }
    // Modifiers applied only to all other operations
    return .detached(
      query: query.retry(limit: 3)
        .enableAutomaticRunning(onlyWhen: .always(true))
        .customModifier()
        .deduplicated(),
      initialState: initialState,
      initialContext: context
    )
  }
}

let client = OperationClient(storeCreator: MyStoreCreator())
```

## Conclusion

In this article, you learned how to apply default values, modfiers, and contexts to your operations.
