#if canImport(Combine)
  import Combine
  import Foundation

  extension QueryStore {
    public struct Publisher: Combine.Publisher, @unchecked Sendable {
      public struct Output: Sendable {
        public let state: State
        public let context: QueryContext
      }
      public typealias Failure = Never

      fileprivate let store: QueryStore<State>

      public func receive(subscriber: some Subscriber<Output, Failure>) {
        let conduit = Conduit(subscriber: subscriber)
        let subscription = self.store.subscribe(
          with: QueryEventHandler { state, context in
            conduit.send(Output(state: state, context: context))
          }
        )
        subscriber.receive(subscription: subscription)
      }
    }

    public var publisher: Publisher {
      Publisher(store: self)
    }
  }

  extension QueryStore.Publisher {
    private final class Conduit<S: Subscriber<Output, Failure>>: @unchecked Sendable {
      private let lock = NSLock()
      private let subscriber: S

      init(subscriber: S) {
        self.subscriber = subscriber
      }

      func send(_ output: Output) {
        self.lock.withLock { _ = self.subscriber.receive(output) }
      }
    }
  }
#endif
