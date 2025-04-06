extension QueryStore {
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
