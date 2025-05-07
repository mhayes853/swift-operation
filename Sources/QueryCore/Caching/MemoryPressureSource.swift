#if canImport(Dispatch)
  import Dispatch
#endif

// MARK: - MemoryPressure

public struct MemoryPressure: RawRepresentable, Sendable, Hashable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
}

extension MemoryPressure {
  public static let normal = Self(rawValue: 1 << 0)
  public static let warning = Self(rawValue: 1 << 1)
  public static let critical = Self(rawValue: 1 << 2)
}

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
      let normalSource = DispatchSource.makeMemoryPressureSource(
        eventMask: .normal,
        queue: self.queue
      )
      normalSource.setEventHandler { handler(.normal) }
      normalSource.resume()

      let warningSource = DispatchSource.makeMemoryPressureSource(
        eventMask: .warning,
        queue: self.queue
      )
      warningSource.setEventHandler { handler(.warning) }
      warningSource.resume()

      let criticalSource = DispatchSource.makeMemoryPressureSource(
        eventMask: .critical,
        queue: self.queue
      )
      criticalSource.setEventHandler { handler(.critical) }
      criticalSource.resume()

      return QuerySubscription {
        normalSource.cancel()
        warningSource.cancel()
        criticalSource.cancel()
      }
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
