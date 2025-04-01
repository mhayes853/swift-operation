import Dependencies
import Foundation
import Query
import Sharing

extension SharedReaderKey where Self == NetworkStatusKey {
  public static var networkStatus: NetworkStatusKey {
    NetworkStatusKey(observer: nil)
  }

  public static func networkStatus(observer: some NetworkObserver) -> NetworkStatusKey {
    NetworkStatusKey(observer: observer)
  }
}

public struct NetworkStatusKey: SharedReaderKey {
  private let observer: any NetworkObserver

  init(observer: (any NetworkObserver)?) {
    @Dependency(\.networkObserver) var networkObserver
    self.observer = observer ?? networkObserver
  }

  public var id: NetworkStatusKeyID {
    NetworkStatusKeyID(observer: self.observer)
  }

  public func load(
    context: LoadContext<NetworkStatus>,
    continuation: LoadContinuation<NetworkStatus>
  ) {
    continuation.resume(returning: self.observer.currentStatus)
  }

  public func subscribe(
    context: LoadContext<NetworkStatus>,
    subscriber: SharedSubscriber<NetworkStatus>
  ) -> SharedSubscription {
    let subscription = self.observer.subscribe { subscriber.yield($0) }
    return SharedSubscription { subscription.cancel() }
  }
}

public struct NetworkStatusKeyID: Hashable, Sendable {
  private let observerIdentifier: ObjectIdentifier

  fileprivate init(observer: any NetworkObserver) {
    self.observerIdentifier = ObjectIdentifier(observer as AnyObject)
  }
}
