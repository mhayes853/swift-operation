#if canImport(Dispatch)
  import Dispatch
#endif

// MARK: - DispatchMemoryPressureSource

#if canImport(Darwin)
  /// A ``MemoryPressureSource`` that uses `DispatchSource.makeMemoryPressureSource` to subscribe
  /// to memory pressure notifications.
  public struct DispatchMemoryPressureSource: MemoryPressureSource, Sendable {
    let queue: DispatchQueue?

    public func subscribe(
      with handler: @escaping @Sendable (MemoryPressure) -> Void
    ) -> OperationSubscription {
      let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: self.queue)
      source.setEventHandler { handler(MemoryPressure(from: source.data)) }
      return OperationSubscription { source.cancel() }
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

// MARK: - MemoryPressure Helper

#if canImport(Darwin)
  extension MemoryPressure {
    /// Creates pressure from dispatch pressure.
    ///
    /// - Parameter dispatchPressure: A `DispatchSource.MemoryPressureEvent`.
    public init(from dispatchPressure: DispatchSource.MemoryPressureEvent) {
      self.init(rawValue: Int(dispatchPressure.rawValue))
    }
  }
#endif
