// MARK: - OperationTaskIdentifier

/// An opaque identifier for a ``OperationTask``.
///
/// Each new `OperationTask` is assigned a unique identifier when it is initialized, you do not create
/// instances of this identifier.
public struct OperationTaskIdentifier: Hashable, Sendable {
  private static let counter = Lock(0)

  static func next() -> Self {
    counter.withLock { counter in
      defer { counter += 1 }
      return Self(number: counter)
    }
  }

  private let number: Int
}

extension OperationTaskIdentifier: CustomDebugStringConvertible {
  public var debugDescription: String {
    "#\(self.number)"
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The ``OperationTaskIdentifier`` of the currently running task, if any.
  public var operationRunningTaskIdentifier: OperationTaskIdentifier? {
    get { self[OperationRunningTaskIdentifierKey.self] }
    set { self[OperationRunningTaskIdentifierKey.self] = newValue }
  }

  private enum OperationRunningTaskIdentifierKey: Key {
    static var defaultValue: OperationTaskIdentifier? {
      nil
    }
  }
}
