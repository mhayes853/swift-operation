import Dependencies
import Foundation
import Query
import Sharing

// MARK: - NetworkStatusKey

extension SharedReaderKey where Self == NetworkStatusKey {
  /// A `SharedReaderKey` that observes the current user's network connection status.
  public static var networkStatus: NetworkStatusKey {
    NetworkStatusKey(observer: nil)
  }

  /// A `SharedReaderKey` that observes the current user's network connection status.
  ///
  /// - Parameter observer: The `NetworkObserver` to use.
  /// - Returns: A ``NetworkStatusKey``.
  public static func networkStatus(observer: some NetworkObserver) -> NetworkStatusKey {
    NetworkStatusKey(observer: observer)
  }
}

/// A `SharedReaderKey` that observes the current user's network connection status.
public struct NetworkStatusKey {
  private let observer: any NetworkObserver

  init(observer: (any NetworkObserver)?) {
    @Dependency(\.defaultNetworkObserver) var networkObserver
    self.observer = observer ?? networkObserver
  }
}

// MARK: - SharedReaderKey Conformance

extension NetworkStatusKey: SharedReaderKey {
  public var id: ID {
    ID(observer: self.observer)
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

extension NetworkStatusKey {
  public struct ID: Hashable, Sendable {
    private let observerIdentifier: ObjectIdentifier

    fileprivate init(observer: any NetworkObserver) {
      self.observerIdentifier = ObjectIdentifier(observer as AnyObject)
    }
  }
}
