#if canImport(Dispatch)
  import Dispatch
#endif

// MARK: - MemoryPressureSource

public protocol MemoryPressureSource: Sendable {
  func subscribe(with handler: @escaping @Sendable (MemoryPressure) -> Void) -> QuerySubscription
}

// MARK: - DispatchMemoryPressureSource

#if canImport(Dispatch)
  public struct DispatchMemoryPressureSource: MemoryPressureSource {
    let queue: DispatchQueue?

    public func subscribe(
      with handler: @escaping @Sendable (MemoryPressure) -> Void
    ) -> QuerySubscription {
      let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: self.queue)
      source.setEventHandler { handler(MemoryPressure(from: source.data)) }
      return QuerySubscription { source.cancel() }
    }
  }

  extension MemoryPressureSource where Self == DispatchMemoryPressureSource {
    public static var dispatch: Self {
      .dispatch(queue: nil)
    }

    public static func dispatch(queue: DispatchQueue?) -> Self {
      DispatchMemoryPressureSource(queue: queue)
    }
  }
#endif
