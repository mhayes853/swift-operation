# Testing

Learn how to best use the library in your app's test suite.

## Overview

Given that testing is only sometimes considered a crucial software development practice, it would be wise to test your operations from time to time. In general, reliably testing code that utilizes async-await can be challenging due to the challenges of managing the time of a Task's execution. However, depending on your usage, you can utilize the tools in the library to make this process easier.

If your operations rely on the default initializer of ``OperationClient``, then retries, backoff, artificial delays, rerunning when the network status flips from offline to online, and rerunning on the app reentering from the background are disabled when running in a test environment.

Let's take a look at how we can test operations depending on your usage of the library.

## Reliable and Deterministic Tests

Depending on your usage of the library, you may implement a class `SomeModel` that utilizes `SomeData.query`.

**Sharing**
```swift
import Observation
import SharingOperation

@MainActor
@Observable
final class SomeModel {
  @ObservationIgnored
  @SharedOperation(SomeData.query) var value
}
```

In a test suite, your first instinct may be to assert on `value`. However, `value` will likely be in a loading state once the test begins, and it's difficult to determine when it will have been loaded.

```swift
@Test
@MainActor
func valueLoads() {
  let model = SomeModel()
  #expect(model.value == nil)

  // Wait for value to load...

  #expect(model.value == "loaded")
}
```

The main issue here is the "Wait for value to load..." comment as it's not exactly clear when `model.value` will have been loaded. To get around this, you can invoke `load` on the `@SharedOperation` property wrapper. Since by default, queries are deduplicated, this will not unnecessarily invoke the query. Rather, it will await for the ongoing fetch call to finish.

```swift
@Test
@MainActor
func valueLoads() async throws {
  let model = SomeModel()
  #expect(model.value == nil)

  try await model.$value.load()

  #expect(model.value == "loaded")
}
```

## Testing Operations Directly

If you find testing an operation through an `@Observable` model to be too cumbersome, you can also opt to test the operation directly through an ``OperationStore``. This will give you manual control over the execution of the operation.

```swift
@Test
func valueLoades() async throws {
  let store = OperationStore.detached(query: SomeData.query)
  #expect(store.currentValue == nil)

  try await store.fetch()

  #expect(store.currentValue == "loaded")
}
```

## Conclusion

The biggest hurdle in testing how your code interacts with your operations is managing to have control over their execution. To clear this hurdle, you can hook into the various APIs provided by the `@SharedOperation` property wrapper, or you can test the operation using an `OperationStore` directly.
