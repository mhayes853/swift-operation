extension OperationStore {
  /// An asynchronous sequence of states from a ``OperationStore``.
  ///
  /// You can obtain an instance of this sequence by calling ``OperationStore/states``, and use
  /// for-await-in syntax to iterate over all state updates from the store.
  ///
  /// ```swift
  /// class Observer {
  ///   init(store: OperationStore<MyQuery.State>) {
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
  public struct AsyncStates: AsyncSequence, Sendable {
    public struct Element: Sendable {
      public let state: State
      public let context: OperationContext
    }

    fileprivate let store: OperationStore<State>

    public struct AsyncIterator: AsyncIteratorProtocol {
      fileprivate var base: AsyncStream<Element>.AsyncIterator

      public mutating func next() async -> Element? {
        await self.base.next()
      }

      @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
      public mutating func next(isolation actor: isolated (any Actor)?) async -> Element? {
        await self.base.next(isolation: actor)
      }
    }

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

  /// An asynchronous sequence of states from a ``OperationStore``.
  ///
  /// You can use for-await-in syntax to loop over all states from this store.
  ///
  /// ```swift
  /// class Observer {
  ///   init(store: OperationStore<MyQuery.State>) {
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
