# Customizing Queries with Modifiers

Learn how to use the `QueryModifier` protocol to reuse and compose query logic.

## Overviews

`QueryModifier` allows you to add reusable logic to queries like how `ViewModifier` allows you to add reusable logic to views in SwiftUI. Retries, deduplication, stale-when-revalidate, and much more are all implemented using the `QueryModifier` protocol. You can also create your own custom modifiers in addition to the ones the library provides.

## Creating a Modifier

Creating a modifier is as easy as conforming to the `QueryModifier` protocol. For this example, we can create a modifier to add an artificial delay to a query.

```swift
struct DelayModifier<Query: QueryRequest>: QueryModifier {
  let seconds: TimeInterval

  func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await context.queryDelayer.delay(for: seconds)
    return try await query.fetch(in: context, with: continuation)
  }
}
```

Then, we can extend `QueryRequest` with a method that applies our custom modifier.

```swift
extension QueryRequest {
  func delay(for seconds: TimeInterval) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(DelayModifier(seconds: seconds))
  }
}
```

> Note: It's essential that we have `ModifiedQuery<Self, some QueryModifier<Self>>` as the return type instead of `some QueryRequest<Value>`. The former style ensures that infinite queries and mutations can use our modifier whilst still being recognized as their respective `InfiniteQueryRequest` or `MutationRequest` conformances by the compiler.

This allows us to use our modifer for any query that we create.

```swift
struct FirstQuery: QueryRequest {
  // ...
}

struct SecondQuery: QueryRequest {
  // ...
}

let query1 = FirstQuery().delay(for: 1)
let query2 = SecondQuery().delay(for: 2)
```

With this, we now have a reusable modifier that can apply an artificial delay to any query that we create.

## Setting Up the Context

Your modifier may want to set up the `QueryContext` it's handed in a certain way. For instance, the retry, query controller, and stale-when-revalidate modifiers use this technique to set overrideable values in the `QueryContext`, such that you can override the context values before running the query.

Let's apply this technique to our custom `DelayModifier`.

```swift
struct DelayModifier<Query: QueryRequest>: QueryModifier {
  let seconds: TimeInterval

  func setup(context: inout QueryContext, using query: Query) {
    context.queryDelay = seconds
    query.setup(context: &context)
  }

  func modify(
    _ query: QueryRequest,
    context: QueryContext,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await context.queryDelayer.delay(for: context.queryDelay)
    return try await query.fetch(in: context, with: continuation)
  }
}

extension QueryContext {
  var queryDelay: TimeInterval {
    get { self[QueryContextKey.self] }
    set { self[QueryContextKey.self] = newValue }
  }

  private enum QueryDelayKey: Key {
    static let defaultValue = 0.3
  }
}
```

This now allows you to override the `queryDelay` value like so.

```swift
let query = SomeQuery().delay(for: 1)
let store = client.store(for: query)
store.context.queryDelay = 0
```

When a `QueryStore` is created, it will run the `setup` method of the `DelayModifier` once which will set the `queryDelay` property to 1 second in the above example. However, after the store is created, the `queryDelay` value is set to 0 which effectively disables the artificial delay.

## Conclusion

In this article, you learned how you can create reusable and composable query logic utilizing the `QueryModifier` protocol. Modifiers can also setup the `QueryContext` in a certain way before the query is ever ran.
