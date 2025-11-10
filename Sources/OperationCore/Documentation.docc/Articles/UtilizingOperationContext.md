# Utilizing the OperationContext

Learn how to best use the ``OperationContext`` to facilitate dependency injection, customizing operation behavior, and much more.

## Overview

The `OperationContext` is a powerful tool used by many types in the library, and is accessible from within an operation. You can use the context as configuration, or even as a way to inject dependencies into your operations.

At it's core, the context is a flexible, strongly typed, and extendable key-value store. This means you can easily add custom properties to it.

Operations and operation modifiers also have the opportunity to setup the context through ``OperationRequest/setup(context:)-9fupm`` and ``OperationModifier/setup(context:using:)-40ul6`` respectively.

Let's now take a look at how you can utilize all of these powers.

## Adding Custom Properties to OperationContext

`OperationContext` behaves a lot like SwiftUI's `EnvironmentValues`, and you can extend it with custom properties in a very similar manner to `EnvironmentValues`.

```swift
import Operation
import SwiftUI

// 🟢 SwiftUI

extension EnvironmentValues {
  @Entry var customProperty = "hello!"
}

// 🟢 OperationContext

extension OperationContext {
  @ContextEntry var customProperty = "hello!"
}
```

Now you can access your custom property inside of operations.

```swift
@QueryRequest
func playerQuery(
  id: Int, 
  context: OperationContext
) async throws -> Player {
  if context.customProperty == "hello!" {
    // Fetch...
  } else {
    // Fetch Differently...
  }
}
```

As can be seen here, we're able to customize the behavior of `PlayerQuery` based on a custom context property. Utilizing this technique allows you to use the `OperationContext` in a variety of ways, some of which we will talk about later.

The `defaultValue` of an ``OperationContext/Key`` is computed everytime the `OperationContext` instance doesn't have an explicitly overriden value. If you want to lazily run an expensive computation for the default value, or use a shared reference, define your default value with a `static let` property.

```swift
extension OperationContext {
  var myExpensiveProperty: String {
    get { self[MyExpensiveLazyPropertyKey.self] }
    set { self[MyExpensiveLazyPropertyKey.self] = newValue }
  }

  private enum MyExpensiveLazyPropertyKey: Key {
    static let defaultValue = someExpensiveComputation()
  }
}
```

## Setting Up The Context

The `OperationRequest` protocol has an optional requirement to setup an `OperationContext` in a way that the operation likes. This method is ran a single time when an ``OperationStore`` for the operation is initialized.

```swift
struct SomeQuery: QueryRequest, Hashable {
  func setup(context: inout OperationContext) {
    context.customProperty = "new value"
  }

  // ...
}
```

When the query runs, the value of `customProperty` will be `"new value"`.

This strategy is used for many operation modifiers. For instance, retries do this to setup the context with the maximum number of retries allowed for the operation. By setting this value in the context, it's possible to disable retries like so.

```swift
struct NoRetryQuery: QueryRequest, Hashable {
  func setup(context: inout OperationContext) {
    context.maxRetries = 0 // Disable retries for this query.
  }

  // ...
}
```

### Overriding Time

``OperationState/valueLastUpdatedAt`` and ``OperationState/errorLastUpdatedAt`` properties on ``OperationState`` conformances are computed using the ``OperationClock`` protocol. The clock lives on the context, and can be overridden. Therefore, if you want to ensure a deterministic date calculations for various reasons (time freeze, testing, etc.), you can inject the following operation clock into in the context.

```swift
let store = OperationStore.detached(
  query: Post.query(for: 1),
  initialValue: nil
)
let date = Date(timeIntervalSince1970: 1234567890)
store.context.operationClock = .custom { date }

try await store.fetch()

#expect(store.valueLastUpdatedAt == date)
```

### Overriding Delays

The ``OperationDelayer`` protocol is used to artificially delay queries in the case of retries. By default, operation retries utilize exponential backoff where the operation will be artificially delayed by an increasing amount of time based on the current retry index.

For testing, this delay may be unacceptable, but thankfully you can override the `OperationDelayer` on the context to remove delays.

```swift
let store = OperationStore.detached(
  query: Post.query(for: 1),
  initialValue: nil
)
store.context.operationDelayer = .noDelay

try await store.fetch() // Will incur no retry delays.
```

> Note: The default initializer of ``OperationClient`` will automatically disable delays for you during tests.

## Conclusion

In this article, we explored how to utilize the `OperationContext` to customize operation behavior, and even use it as a tool for dependency injection within operations. `OperationContext` can be extended with custom properties like SwiftUI's `EnvironmentValues`, and operations even have the opportunity to setup the context before running.
