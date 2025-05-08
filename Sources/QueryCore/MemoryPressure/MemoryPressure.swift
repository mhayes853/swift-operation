#if canImport(Dispatch)
  import Dispatch
#endif

// MARK: - MemoryPressure

/// A data type describing the severity of memory pressure.
public struct MemoryPressure: RawRepresentable, Sendable, Hashable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
}

// MARK: - OptionSet

extension MemoryPressure: OptionSet {
  /// Normal severity.
  public static let normal = Self(rawValue: 1 << 0)
  
  /// Warning severity.
  public static let warning = Self(rawValue: 1 << 1)
  
  /// Critical severity.
  public static let critical = Self(rawValue: 1 << 2)

  /// The default severities in which ``QueryClient/DefaultStoreCache`` should evict store entries
  /// upon receiving a memory pressure notification.
  public static let defaultEvictable: Self = [.warning, .critical]
  
  /// All severities.
  public static let all: Self = [.normal, .warning, .critical]
}

// MARK: - Dispatch Helpers

#if canImport(Dispatch)
  extension MemoryPressure {
    /// Creates pressure from dispatch pressure.
    ///
    /// - Parameter dispatchPressure: A `DispatchSource.MemoryPressureEvent`.
    public init(from dispatchPressure: DispatchSource.MemoryPressureEvent) {
      self.init(rawValue: Int(dispatchPressure.rawValue))
    }
  }
#endif
