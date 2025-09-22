import Dependencies
import Foundation
import Operation
import Sharing

// MARK: - NetworkConnectionStatusKey

extension SharedReaderKey where Self == NetworkConnectionStatusKey {
  /// A `SharedReaderKey` that observes the current user's network connection status.
  public static var networkStatus: NetworkConnectionStatusKey {
    NetworkConnectionStatusKey(observer: nil)
  }

  /// A `SharedReaderKey` that observes the current user's network connection status.
  ///
  /// - Parameter observer: The `NetworkObserver` to use.
  /// - Returns: A ``NetworkConnectionStatusKey``.
  public static func networkStatus(
    observer: some NetworkObserver & Sendable
  ) -> NetworkConnectionStatusKey {
    NetworkConnectionStatusKey(observer: observer)
  }
}

/// A `SharedReaderKey` that observes the current user's network connection status.
public struct NetworkConnectionStatusKey: SharedReaderKey {
  private let observer: any NetworkObserver & Sendable

  public var id: ID {
    ID(observer: self.observer)
  }

  init(observer: (any NetworkObserver & Sendable)?) {
    @Dependency(\.defaultNetworkObserver) var networkObserver
    self.observer = observer ?? networkObserver
  }

  public func load(
    context: LoadContext<NetworkConnectionStatus>,
    continuation: LoadContinuation<NetworkConnectionStatus>
  ) {
    continuation.resume(returning: self.observer.currentStatus)
  }

  public func subscribe(
    context: LoadContext<NetworkConnectionStatus>,
    subscriber: SharedSubscriber<NetworkConnectionStatus>
  ) -> SharedSubscription {
    let subscription = self.observer.subscribe { subscriber.yield($0) }
    return SharedSubscription { subscription.cancel() }
  }
}

// MARK: - ID

extension NetworkConnectionStatusKey {
  public struct ID: Hashable, Sendable {
    private let observerIdentifier: ObjectIdentifier

    fileprivate init(observer: any NetworkObserver) {
      self.observerIdentifier = ObjectIdentifier(observer as AnyObject)
    }
  }
}
