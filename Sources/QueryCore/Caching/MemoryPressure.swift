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

// MARK: - OptionSet

extension MemoryPressure: OptionSet {
  public static let normal = Self(rawValue: 1 << 0)
  public static let warning = Self(rawValue: 1 << 1)
  public static let critical = Self(rawValue: 1 << 2)

  public static let defaultEvictable: Self = [.warning, .critical]
  public static let all: Self = [.normal, .warning, .critical]
}

// MARK: - Dispatch Helpers

#if canImport(Dispatch)
  extension MemoryPressure {
    public init(from dispatchPressure: DispatchSource.MemoryPressureEvent) {
      self.init(rawValue: Int(dispatchPressure.rawValue))
    }
  }
#endif
