// MARK: - MemoryPressure

/// A data type describing the severity of memory pressure.
public struct MemoryPressure: RawRepresentable, Sendable, Hashable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
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

  /// The default severities in which ``OperationClient/DefaultStoreCache`` should evict store entries
  /// upon receiving a memory pressure notification.
  public static let defaultEvictable: Self = [.warning, .critical]

  /// All severities.
  public static let all: Self = [.normal, .warning, .critical]
}
