# Testing Queries

Learn how to best use the library in your app's test suite.

## Overview

Given that testing is sometimes considered a crucial practice, it would be wise to test how your queries interact with your app. In general, reliably testing code that utilizes async await can be challenging due to the challenges of managing the time of a Task's execution. However, depending on your usage, you can utilize the tools in the library to make this process easier.

By default, query retries are disabled when running queries in a test environment, additionally no backoff or delays are applied to any query.

Let's take a look at how we can test queries depending on your usage of the library.

## Sharing

If you utilize the Sharing library to observe your query's state, your code may look like this.

```swift
import Observation
import SharingQuery

@MainActor
@Observable
final class SomeModel {
  @ObservationIgnored
  @Shared(.query(SomeQuery())) var value
}
```

In a test suite, your first instinct may be to assert on `value`. However, `value` will likely be in a loading state once the test begins, and it's difficult to determine when it will have been loaded.

```swift
@MainActor
@Test
func valueLoads() {
  let model = SomeModel()
  #expect(model.$value.isLoading)
  #expect(model.value == nil)

  // Wait for value to load...

  #expect(!model.$value.isLoading)
  #expect(model.value == "loaded")
}
```

The main issue here is the "Wait for value to load..." comment as it's not exactly clear when `model.value` will have been loaded. To get around this, you can technically reach into the `QueryStore` for `SomeQuery`, and await the first active task in the store.

```swift
@MainActor
@Test
func valueLoads() async throws {
  @Dependency(\.queryClient) var client

  let model = SomeModel()
  #expect(model.$value.isLoading)
  #expect(model.value == nil)

  _ = try await client.store(for: SomeQuery()).activeTasks.first?.runIfNeeded()

  #expect(!model.$value.isLoading)
  #expect(model.value == "loaded")
}
```

This will work, yet it's a quite annoying syntax.

Another approach is to override the defaults applied to each query in the `QueryClient` such that automatic fetching is disabled. That way, you can manually trigger the query's execution. This can be done by overriding `@Dependency(\.queryClient)` with a client that disables automatic fetching.

```swift
@MainActor
@Test(.dependencies {
  $0.queryClient = QueryClient(
    storeCreator: .defaults(retryLimit: 0, queryEnableAutomaticFetchingCondition: .always(false))
  )
})
func valueLoads() async throws {
  let model = SomeModel()
  #expect(model.$value.isLoading)
  #expect(model.value == nil)

  try await model.$value.load()

  #expect(!model.$value.isLoading)
  #expect(model.value == "loaded")
}
```

Now you can manually trigger execution of the query, ensuring that we have a deterministic way to assert on the model's value.

## Combine

If you utilize combine to observe your query's state, your code may look like this.

```swift
import Query
import Combine

@MainActor
final class SomeViewModel: ObservableObject {
  @Published var value: String?
  private var cancellables = Set<AnyCancellable>()

  init(client: QueryClient) {
    let store = client.store(for: SomeStringQuery())
    store
      .publisher
      .sink { [weak self] output in
        self?.value = output.state.currentValue
      }
      .store(in: &cancellables)
  }
}
```

In a test suite, your first instinct may be to assert on `value`. However, `value` will likely be in a loading state once the test begins, and it's difficult to determine when it will have been loaded.

```swift
@MainActor
@Test
func valueLoads() {
  let model = SomeViewModel(client: QueryClient())
  #expect(model.value == nil)

  // Wait for value to load...

  #expect(model.value == "loaded")
}
```

The main issue here is the "Wait for value to load..." comment as it's not exactly clear when `model.value` will have been loaded. To get around this, you can technically reach into the `QueryStore` for `SomeQuery`, and await the first active task in the store.

```swift
@MainActor
@Test
func valueLoads() async throws {
  let client = QueryClient()

  let model = SomeViewModel(client: client)
  #expect(model.value == nil)

  _ = try await client.store(for: SomeQuery()).activeTasks.first?.runIfNeeded()

  #expect(model.value == "loaded")
}
```

This will work, yet it's a quite annoying syntax.

Another approach is to override the defaults applied to each query in the `QueryClient` such that automatic fetching is disabled. That way, you can manually trigger the query's execution.

```swift
@MainActor
@Test
func valueLoads() async throws {
  let client = QueryClient(
    storeCreator: .defaults(retryLimit: 0, queryEnableAutomaticFetchingCondition: .always(false))
  )

  let model = SomeViewModel(client: client)
  #expect(model.value == nil)

  try await client.store(for: SomeQuery()).fetch()

  #expect(model.value == "loaded")
}
```

Now you can manually trigger execution of the query, ensuring that we have a deterministic way to assert on the model's value.

## Pure Swift

If you utilize `QueryStore` directly to observe your query's state, your code may look like this.

```swift
import Query

@MainActor
final class SomeClass {
  var value: String?
  private var subscriptions = Set<QuerySubscription>()

  init(client: QueryClient) {
    let store = client.store(for: SomeQuery())
    store.subscribe(
      with: QueryEventHandler { [weak self] state, _ in
        Task { @MainActor in
          self?.value = state.currentValue
        }
      }
    )
    .store(in: &subscriptions)
  }
}
```

In a test suite, your first instinct may be to assert on `value`. However, `value` will likely be in a loading state once the test begins, and it's difficult to determine when it will have been loaded.

```swift
@MainActor
@Test
func valueLoads() {
  let model = SomeClass(client: QueryClient())
  #expect(model.value == nil)

  // Wait for value to load...

  #expect(model.value == "loaded")
}
```

The main issue here is the "Wait for value to load..." comment as it's not exactly clear when `model.value` will have been loaded. To get around this, you can technically reach into the `QueryStore` for `SomeQuery`, and await the first active task in the store.

```swift
@MainActor
@Test
func valueLoads() async throws {
  let client = QueryClient()

  let model = SomeClass(client: client)
  #expect(model.value == nil)

  _ = try await client.store(for: SomeQuery()).activeTasks.first?.runIfNeeded()

  #expect(model.value == "loaded")
}
```

This will work, yet it's a quite annoying syntax.

Another approach is to override the defaults applied to each query in the `QueryClient` such that automatic fetching is disabled. That way, you can manually trigger the query's execution.

```swift
@MainActor
@Test
func valueLoads() async throws {
  let client = QueryClient(
    storeCreator: .defaults(retryLimit: 0, queryEnableAutomaticFetchingCondition: .always(false))
  )

  let model = SomeClass(client: client)
  #expect(model.value == nil)

  try await client.store(for: SomeQuery()).fetch()

  #expect(model.value == "loaded")
}
```

Now you can manually trigger execution of the query, ensuring that we have a deterministic way to assert on the model's value.

## Conclusion

The biggest hurdle in testing how your code interacts with your queries is managing to have control over the query's execution. To clear this hurdle, you can either reach into the `QueryStore` and await the first active `QueryTask`, or you can override the `QueryClient` to disable automatic fetching.
