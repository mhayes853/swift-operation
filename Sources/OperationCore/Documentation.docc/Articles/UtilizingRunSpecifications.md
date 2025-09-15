# Utilizing Run Specifications

Learn how to best use the ``OperationRunSpecification`` protocol to control how and when queries can fetch their data.

## Overview

The `OperationRunSpecification` protocol describes a set of conditions that can be used to determine when a query should fetch its data. For instance, ``NetworkConnectionRunSpecification`` utilizes a ``NetworkObserver`` to determine whether or not the current network connection status is suitable for fetching data. Additionally, ``ApplicationIsActiveRunSpecification`` listens for changes in the app's resign active state, which allows for automatic refetching when the app becomes active again.

The library provides many built-in modifiers that utilize fetch conditions. Let's explore how some of these modifiers work, and how you can create your own `OperationRunSpecification` conformances that take advantage of these modifiers.

## Automatic Fetching

``OperationStore`` has a notion of automatic running, which essentially means that the operation can be run without having to manually call `run` on the store. You can check whether or not automatic running is enabled on your `OperationStore` via the `isAutomaticRunningEnabled` property. By default, all ``QueryRequest`` and ``PaginatedRequest`` conformances have automatic fetching enabled, and all ``MutationRequest`` conformances have automatic fetching disabled.

Automatic fetching covers the following scenarios:
- Fetching when a new subscription to the store is added via ``OperationStore/subscribe(with:)-(OperationEventHandler<State>)``.
- Fetching from within a ``OperationController``.
  - This includes automatically refetching based on changes to `OperationRunSpecification`s.

To control whether or not automatic fetching is enabled, you can utilize the ``OperationRequest/enableAutomaticRunning(onlyWhen:)`` modifier alongside a `OperationRunSpecification`.

```swift
struct MyQuery: QueryRequest {
  // ...
}

// Automatic running is always disabled for this query.
let query = MyQuery().disableAutomaticRunning()
```

However, it's also possible to disable it when the network is down by using `NetworkConnectionRunSpecification`.

```swift
let query = MyQuery().enableAutomaticRunning(
  when: .connected(to: NWPathMonitorObserver.shared)
)
```

> Note: In browser applications (WASM), you can use `NavigatorObserver.shared` which utilizes [`window.navigator`](https://developer.mozilla.org/en-US/docs/Web/API/Navigator) under the hood to observe network connectivity changes.

## Refetching On Change Of Conditions

Another modifier that utilizes fetch conditions is the ``StatefulOperationRequest/rerunOnChange(of:)`` modifier. This modifier allows you to specify a `OperationRunSpecification` that will trigger a refetch when the condition changed to true.

```swift
let query = MyQuery().rerunOnChange(
  of: .connected(to: NWPathMonitorObserver.shared)
)
```

The example above will refetch the query whenever the network comes back online after being down.

## Stale When Revalidate

`OperationStore` has a notion of stale-when-revalidate when fetching data. When a new subscriber is added to the store via ``OperationStore/subscribe(with:)-(OperationEventHandler<State>)``, the store will refetch the data if both ``OperationStore/isStale`` and ``OperationStore/isAutomaticRunningEnabled`` are true. You can control the value of `isStale` via a `OperationRunSpecification`.

```swift
import Combine

let subject = PassthroughSubject<Bool, Never>()
let query = MyQuery().staleWhen(
  condition: .observing(publisher: subject, initialValue: true)
)
```

In this example, the query will be considered stale when the subject emits a value of `true`.

> Note: Chaining multiple modifiers prefixed with `stale` will mark the query as stale when any one of those modifiers' conditions are met. In other words, the following code snippets are functionality equivalent.
> ```swift
> // query and query2 are functionality equivalent.
>
> let query = MyQuery()
>   .staleWhen(condition: .notificationFocus)
>   .staleWhen(condition: .connected(to: NWPathMonitorObserver.shared))
>
> let query2 = MyQuery().staleWhen(
>   condition:
>     .notificationFocus || .connected(to: NWPathMonitorObserver.shared)
> )
> ```

## Boolean Operators

The ``!(_:)``, ``||(_:_:)``, and ``&&(_:_:)`` operators have been overloaded for the `OperationRunSpecification` protocol. This allows you to compose conditions just like you would with booleans.

```swift
let query = MyQuery().staleWhen(
  condition:
    .connected(to: NWPathMonitorObserver.startingShared()) && .notificationFocus
)
```

This condition marks the query as stale when both the network is connected and when the app is currently active in the foreground.

## Custom Fetch Conditions

You can also define your own fetch conditions by conforming to the `OperationRunSpecification` protocol. For instance, you may want to make a condition to detect whether or not a user is logged in.

```swift
protocol UserAuthentication {
  var accessToken: String? { get }
  func subscribe(
    _ observer: @escaping @Sendable (String?) -> Void
  ) -> Cancellable
}

struct UserLoggedInRunSpecification<
  Auth: UserAuthentication
>: OperationRunSpecification {
  let auth: Auth

  func isSatisfied(in context: OperationContext) -> Bool {
    auth.accessToken != nil
  }

  func subscribe(
    in context: OperationContext,
    onChange handler: @escaping @Sendable () -> Void
  ) -> OperationSubscription {
    observer(isSatisfied(in: context))
    let subscription = auth.subscribe { _ in observer() }
    return OperationSubscription { subscription.cancel() }
  }
}
```

Now you can use this condition to add powerful functionality, such as refetching all a query when a new user signs in.

```swift
final class FirebaseAuthentication: UserAuthentication {
  // ...
}

let query = MyQuery().refetchOnChange(
  of: UserLoggedInCondition(auth: FirebaseAuthentication())
)
```

## Conclusion

In this article, you learned how the `OperationRunSpecification` protocol can be used to detect conditions for whether or not fetching data is suitable for a query. Alongside implementing your own `OperationRunSpecification`s, you can also utilize the powerful built-in modifiers that allow you to refetch when a condition changes, and much more.
