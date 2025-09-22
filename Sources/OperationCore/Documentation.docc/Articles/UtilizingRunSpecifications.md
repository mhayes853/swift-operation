# Utilizing Run Specifications

Learn how to best use the ``OperationRunSpecification`` protocol to control how and when operations can automatically run.

## Overview

The `OperationRunSpecification` protocol describes a set of conditions that can be used to determine when an operation should run automatically. For instance, ``NetworkConnectionRunSpecification`` utilizes a ``NetworkObserver`` to determine whether or not the current network connection status is suitable for running an operation. Additionally, ``ApplicationIsActiveRunSpecification`` listens for changes in the app's foreground state, which allows for rerunning when the app reenters the foreground from the background.

The library provides many built-in modifiers that utilize run specifications. Let's explore how some of these modifiers work, and how you can create your own `OperationRunSpecification` conformances that take advantage of these modifiers.

## Automatic Running

Automatic running is defined as the process of running an operation without explicitly calling ``OperationStore/run(using:handler:)``. This includes, but is not limited to:
1. Running when subscribed to vian ``OperationStore/subscribe(with:)-(OperationEventHandler<State>)``.
2. Running when the app re-enters the foreground from the background.
3. Running when the user's network connection flips from offline to online.
4. Running via an ``OperationController``.
5. Running via the ``StatefulOperationRequest/rerunOnChange(of:)`` modifier.

When automatic running is disabled, you are responsible for manually calling ``OperationStore/run(using:handler:)`` to ensure that your operation always has the latest data. Methods that work on specific operation types such as ``OperationStore/mutate(using:handler:)`` will call ``OperationStore/run(using:handler:)`` under the hood for you.

When you use the default initializer of an ``OperationClient``, automatic running is enabled for all stores backed by ``QueryRequest`` and ``PaginatedRequest`` operations, and disabled for all stores backed by ``MutationRequest`` operations.

To control whether or not automatic running is enabled, you can utilize the ``StatefulOperationRequest/enableAutomaticRunning(onlyWhen:)`` modifier alongside an `OperationRunSpecification`.

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
  when: .connected(to: NWPathMonitorObserver.startingShared())
)
```

> Note: In browser applications (WASM), you use `NavigatorOnlineObserver.shared` which utilizes [`window.navigator`](https://developer.mozilla.org/en-US/docs/Web/API/Navigator) under the hood instead of ``NWPathMonitorObserver`` to observe network connectivity changes.

## Rerunning When a Specification is Satisfied

Another modifier that utilizes specifications is the ``StatefulOperationRequest/rerunOnChange(of:)`` modifier. This modifier allows you to specify an `OperationRunSpecification` that will trigger a rerun when the specification changes to be satisfied.

```swift
let query = MyQuery().rerunOnChange(
  of: .connected(to: NWPathMonitorObserver.shared)
)
```

The example above will rerun the query whenever the network status flips from offline to online.

## Stale When Revalidate

`OperationStore` has a notion of stale-when-revalidate with respect to its latest held data. When a new subscriber is added to the store vian ``OperationStore/subscribe(with:)-(OperationEventHandler<State>)``, the store will rerun its operation if both ``OperationStore/isStale`` and ``OperationStore/isAutomaticRunningEnabled`` are true. It's possible to control the value of `isStale` via an `OperationRunSpecification`.

```swift
import Combine

let subject = PassthroughSubject<Bool, Never>()
let query = MyQuery().staleWhen(
specification: .observing(publisher: subject, initialValue: true)
)
```

In this example, the query will be considered stale when the subject emits a value of `true`.

> Note: Chaining multiple modifiers prefixed with `stale` will mark the query as stale when any one of those modifiers' specifications are satisfied. In other words, the following code snippets are functionality equivalent.
> ```swift
> // query and query2 are functionality equivalent.
>
> let query = MyQuery()
>   .staleWhen(specification: .applicationIsActive(observer: UIApplicationActivityObserver.shared))
>   .staleWhen(specification: .connected(to: NWPathMonitorObserver.shared))
>
> let query2 = MyQuery().staleWhen(
>   specification:
>     .applicationIsActive(observer: UIApplicationActivityObserver.shared))
>       || .connected(to: NWPathMonitorObserver.shared)
> )
> ```

## Boolean Operators

The ``!(_:)``, ``||(_:_:)``, and ``&&(_:_:)`` operators have been overloaded for the `OperationRunSpecification` protocol. This allows you to compose specifications just like you would with booleans.

```swift
let query = MyQuery().staleWhen(
  specification:
    .connected(to: NWPathMonitorObserver.startingShared())
      && .applicationIsActive(observer: UIApplicationActivityObserver.shared))
)
```

This condition marks the query as stale when both the network is connected and when the app is currently active in the foreground.

## Custom Run Specifications

You can also define your own specifications by conforming to the `OperationRunSpecification` protocol. For instance, you may want to make a specification to detect whether or not a user is logged in to your app.

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
    handler(isSatisfied(in: context))
    let subscription = auth.subscribe { _ in handler() }
    return OperationSubscription { subscription.cancel() }
  }
}
```

Now you can use this specification to add powerful functionality, such as rerunning a query when a new user signs in.

```swift
final class FirebaseAuthentication: UserAuthentication {
  // ...
}

let query = MyQuery().rerunOnChange(
  of: UserLoggedInRunSpecification(auth: FirebaseAuthentication())
)
```

## Conclusion

In this article, you learned how the `OperationRunSpecification` protocol can be used to determine when an operation should automatically run. Alongside implementing your own `OperationRunSpecification`s, you can also utilize the powerful built-in modifiers that automate operation runs.
