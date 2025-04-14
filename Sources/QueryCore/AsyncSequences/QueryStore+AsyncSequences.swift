extension QueryStore {
  /// An asynchronous sequence of states from a ``QueryStore``.
  ///
  /// You can obtain an instance of this sequence by calling ``QueryStore/states``, and use
  /// for-await-in syntax to iterate over all state updates from the store.
  ///
  /// ```swift
  /// class Observer {
  ///   init(store: QueryStore<MyQuery.State>) {
  ///     let task = Task {
  ///       for await element in store.states {
  ///         print("State", element.state, element.context)
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// For every `AsyncIterator` created with this sequence, a new subscription is added to the
  /// underlying store.
  public struct AsyncStates: AsyncSequence {
    public struct Element {
      public let state: State
      public let context: QueryContext
    }

    fileprivate let store: QueryStore<State>

    public func makeAsyncIterator() -> AsyncIterator {
      let stream = AsyncStream<Element> { continuation in
        let subscription = self.store.subscribe(
          with: QueryEventHandler { state, context in
            continuation.yield(Element(state: state, context: context))
          }
        )
        continuation.onTermination = { _ in subscription.cancel() }
      }
      return AsyncIterator(base: stream.makeAsyncIterator())
    }
  }

  /// An asynchronous sequence of states from a ``QueryStore``.
  ///
  /// You can use for-await-in syntax to loop over all states from this store.
  ///
  /// ```swift
  /// class Observer {
  ///   init(store: QueryStore<MyQuery.State>) {
  ///     let task = Task {
  ///       for await element in store.states {
  ///         print("State", element.state, element.context)
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// For every `AsyncIterator` created with this sequence, a new subscription is added to the
  /// underlying store.
  public var states: AsyncStates {
    AsyncStates(store: self)
  }
}

extension QueryStore.AsyncStates {
  public struct AsyncIterator: AsyncIteratorProtocol {
    fileprivate var base: AsyncStream<Element>.AsyncIterator

    public mutating func next() async -> Element? {
      await self.base.next()
    }
  }
}
