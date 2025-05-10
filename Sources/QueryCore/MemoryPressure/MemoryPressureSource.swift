#if canImport(Dispatch)
  import Dispatch
#endif

// MARK: - MemoryPressureSource

/// A protocol for observing memory pressure notifications.
///
/// ``QueryClient/DefaultStoreCache`` uses this protocol to evict inactive stores whenever a new
/// pressure notification is received.
public protocol MemoryPressureSource: Sendable {
  /// Subcribes to pressure notifications from this source.
  ///
  /// - Parameter handler: A handler to run whenever a new notification is emitted.
  /// - Returns: A ``QuerySubscription``.
  func subscribe(with handler: @escaping @Sendable (MemoryPressure) -> Void) -> QuerySubscription
}

// MARK: - DispatchMemoryPressureSource

#if canImport(Darwin)
  /// A ``MemoryPressureSource`` that uses `DispatchSource.makeMemoryPressureSource` to subscribe
  /// to memory pressure notifications.
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
    /// A ``MemoryPressureSource`` that uses `DispatchSource.makeMemoryPressureSource` to subscribe
    /// to memory pressure notifications.
    public static var dispatch: Self {
      .dispatch(queue: nil)
    }

    /// A ``MemoryPressureSource`` that uses `DispatchSource.makeMemoryPressureSource` to subscribe
    /// to memory pressure notifications.
    ///
    /// - Parameter queue: The queue to observe pressure notifications on.
    public static func dispatch(queue: DispatchQueue?) -> Self {
      DispatchMemoryPressureSource(queue: queue)
    }
  }
#endif
