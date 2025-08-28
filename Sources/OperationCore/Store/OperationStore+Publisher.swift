#if canImport(Combine)
  import Combine
  import Foundation

  extension OperationStore {
    /// A Combine `Publisher` that emits state updates from a ``OperationStore``.
    ///
    /// This publisher will add a new subscription to the underlying store when subscribed to.
    public struct Publisher: Combine.Publisher, @unchecked Sendable {
      public struct Output: Sendable {
        public let state: State
        public let context: OperationContext
      }
      public typealias Failure = Never

      fileprivate let store: OperationStore<State>

      public func receive(subscriber: some Subscriber<Output, Failure>) {
        let conduit = Conduit(subscriber: subscriber)
        let subscription = self.store.subscribe(
          with: OperationEventHandler { state, context in
            conduit.send(Output(state: state, context: context))
          }
        )
        subscriber.receive(subscription: CombineOperationSubscription(subscription))
      }
    }

    /// A Combine `Publisher` that emits state updates from this store.
    ///
    /// The publisher will add a new subscription to this store when subscribed to.
    public var publisher: Publisher {
      Publisher(store: self)
    }
  }

  extension OperationStore.Publisher {
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
