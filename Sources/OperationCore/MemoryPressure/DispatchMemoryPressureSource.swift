#if canImport(Darwin)
  import Dispatch

  // MARK: - DispatchMemoryPressureSource

  /// A ``MemoryPressureSource`` backed by `DispatchSource.makeMemoryPressureSource`.
  public struct DispatchMemoryPressureSource: MemoryPressureSource, Sendable {
    private let queue: DispatchQueue?

    /// Creates a memory pressure source backed by `DispatchSource.makeMemoryPressureSource`.
    ///
    /// - Parameter queue: The queue to observer pressure notifications on.
    public init(queue: DispatchQueue?) {
      self.queue = queue
    }

    public func subscribe(
      with handler: @escaping @Sendable (MemoryPressure) -> Void
    ) -> OperationSubscription {
      let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: self.queue)
      source.setEventHandler { handler(MemoryPressure(from: source.data)) }
      return OperationSubscription { source.cancel() }
    }
  }

  extension MemoryPressureSource where Self == DispatchMemoryPressureSource {
    /// A ``MemoryPressureSource`` backed by `DispatchSource.makeMemoryPressureSource`.
    public static var dispatch: Self {
      .dispatch(queue: nil)
    }

    /// A ``MemoryPressureSource`` backed by `DispatchSource.makeMemoryPressureSource`.
    ///
    /// - Parameter queue: The queue to observe pressure notifications on.
    public static func dispatch(queue: DispatchQueue?) -> Self {
      DispatchMemoryPressureSource(queue: queue)
    }
  }

  // MARK: - MemoryPressure Helper

  extension MemoryPressure {
    /// Creates pressure from dispatch pressure.
    ///
    /// - Parameter dispatchPressure: A `DispatchSource.MemoryPressureEvent`.
    public init(from dispatchPressure: DispatchSource.MemoryPressureEvent) {
      self.init(rawValue: UInt32(dispatchPressure.rawValue))
    }
  }
#endif
