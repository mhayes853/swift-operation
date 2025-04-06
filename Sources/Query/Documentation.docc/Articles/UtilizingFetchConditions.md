# Utilizing Fetch Conditions

Learn how to best use the `FetchCondition` protocol to control how and when queries can fetch their data.

## Overview

The `FetchCondition` protocol describes a set of conditions that can be used to determine when a query should fetch its data. For instance, `ConnectedCondition` utilizes a `NetworkObserver` to determine whether or not the current network connection status is suitable for fetching data. Additionally, `NotificationFocusCondition` (or `WindowFocusCondition` on WASM) listens for changes in the app's resign active state, which allows for automatic refetching when the app becomes active again.

The library provides many built-in modifiers that utilize fetch conditions. Let's explore how some of these modifiers work, and how you can create your own `FetchCondition` conformances that take advantage of these modifiers.

## Automatic Fetching

`QueryStore` has a notion of automatic fetching, which essentially means that the data for the query in the store can be fetched without having to manually call `fetch` on the store. You can check whether or not automatic fetching is enabled on your `QueryStore` via the `isAutomaticFetchingEnabled` property. By default, all `QueryRequest` conformances have automatic fetching enabled, and all `MutationRequest` conformances have automatic fetching disabled.

Automatic fetching covers the following scenarios:
- Fetching when a new subscription to the store is added via `subscribe`.
- Fetching from within a `QueryController`.
  - This includes automatically refetching based on changes to `FetchCondition`s.

To control whether or not automatic fetching is enabled, you can utilize the `enableAutomaticFetching` modifier alongside a `FetchCondition`.

```swift
struct MyQuery: QueryRequest {
  // ...
}

// Automatic fetching is always disabled for this query.
let query = MyQuery().enableAutomaticFetching(when: .always(false))
```

However, it's also possible to disable it when the network is down by using `ConnectedCondition`.

```swift
let query = MyQuery().enableAutomaticFetching(when: .connected(to: NWPathMonitorObserver.shared))
```

> Note: In browser applications (WASM), you can use `NavigatorObserver.shared` which utilizes [`window.navigator`](https://developer.mozilla.org/en-US/docs/Web/API/Navigator) under the hood to observe network connectivity changes.

## Refetching On Change Of Conditions

Another modifier that utilizes fetch conditions is the `refetchOnChangeOf` modifier. This modifier allows you to specify a `FetchCondition` that will trigger a refetch when the condition changed to true.

```swift
let query = MyQuery().refetchOnChange(of: .connected(to: NWPathMonitorObserver.shared))
```

The example above will refetch the query whenever the network comes back online after being down.

## Stale When Revalidate

`QueryStore` has a notion of stale-when-revalidate when fetching data. When a new subscriber is added to the store via `subscribe`, the store will refetch the data if both `isStale` and `isAutomaticFetchingEnabled` are true. You can control the value of `isStale` via a `FetchCondition`.

```swift
import Combine

let subject = PassthroughSubject<Bool, Never>()
let query = MyQuery().staleWhen(condition: .observing(publisher: subject, initialValue: true))
```

In this example, the query will be considered stale when the subject emits a value of `true`.

## Suspending Queries

It's also possible to keep a query in a loading state while some condition is false. This can be achieved with the `suspending` modifier.

```swift
let query = MyQuery().suspending(on: .connected(to: NWPathMonitorObserver.shared))

let store = client.store(for: query)
try await store.fetch() // Will suspend while the network is down.
```

In this example, the query will be stuck in a loading state while the network is down. Once the network comes back onlines, the query will resume fetching.

> Note: If your query is powered by `URLSession`, you may also decide to configure the session to suspend when the network is down via [`waitsForConnectivity`](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/2908812-waitsforconnectivity).

## Boolean Operators

The `!`, `||`, and `&&` operators have been overloaded for the `FetchConditon` protocol. This allows you to compose conditions just like you would with booleans.

```swift
let query = MyQuery().staleWhen(condition: .connected(to: NWPathMonitorObserver.shared) && .notificationFocus)
```

This condition marks the query as stale when both the network is connected and when the app is currently active in the foreground.

## Custom Fetch Conditions

You can also define your own fetch conditions by conforming to the `FetchCondition` protocol. For instance, you may want to make a condition to detect whether or not a user is logged in.

```swift
protocol UserAuthentication {
  var accessToken: String? { get }
  func subscribe(_ observer: @escaping @Sendable (String?) -> Void) -> Cancellable
}

struct UserLoggedInCondition<Auth: UserAuthentication>: FetchCondition {
  let auth: Auth

  func isSatisfied(in context: QueryContext) -> Bool {
    auth.accessToken != nil
  }

  func subscribe(
    in context: QueryContext,
    _ observer: @escaping @Sendable (Bool) -> Void
  ) -> QuerySubscription {
    observer(isSatisfied(in: context))
    let subscription = auth.subscribe { accessToken in
      observer(accessToken != nil)
    }
    return QuerySubscription { subscription.cancel() }
  }
}
```

Now you can use this condition to add powerful functionality, such as refetching all a query when a new user signs in.

```swift
final class FirebaseAuthentication: UserAuthentication {
  // ...
}

let query = MyQuery().refetchOnChange(of: UserLoggedInCondition(auth: FirebaseAuthentication()))
```

## Conclusion

In this article, you learned how the `FetchCondition` protocol can be used to detect conditions for whether or not fetching data is suitable for a query. Alongside implementing your own `FetchCondition`s, you can also utilize the powerful built-in modifiers that allow you to refetch when a condition changes, and much more.
