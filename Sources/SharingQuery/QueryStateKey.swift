import Query
import Sharing

// MARK: - QueryStateKey

extension SharedReaderKey {
  public static func queryState<State>(store: QueryStore<State>) -> Self
  where Self == QueryStateKey<State> {
    QueryStateKey(store: store)
  }

}

public struct QueryStateKey<State: QueryStateProtocol> {
  public let store: QueryStore<State>
}

extension QueryStateKey: SharedReaderKey {
  public var id: QueryStateKeyID {
    QueryStateKeyID(storeIdentifier: ObjectIdentifier(store))
  }

  public func load(context: LoadContext<State>, continuation: LoadContinuation<State>) {

  }

  public func subscribe(
    context: LoadContext<State>,
    subscriber: SharedSubscriber<State>
  ) -> SharedSubscription {
    SharedSubscription {}
  }
}

// MARK: - QueryStateKeyID

public struct QueryStateKeyID: Hashable, Sendable {
  fileprivate let storeIdentifier: ObjectIdentifier
}

// MARK: - SharedReader Init

extension SharedReader where Value: QueryStateProtocol {
  public init(_ key: QueryStateKey<Value>) {
    self.init(wrappedValue: key.store.state, key)
  }
}
