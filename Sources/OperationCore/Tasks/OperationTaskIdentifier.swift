import Atomics

// MARK: - OperationTaskIdentifier

/// An opaque identifier for a ``OperationTask``.
///
/// Each new `OperationTask` is assigned a unique identifier when it is initialized, you do not create
/// instances of this identifier.
public struct OperationTaskIdentifier: Hashable, Sendable {
  private static let counter = ManagedAtomic(0)

  static func next() -> Self {
    Self(number: Self.counter.wrappingIncrementThenLoad(by: 1, ordering: .relaxed))
  }

  private let number: Int
}

extension OperationTaskIdentifier: CustomDebugStringConvertible {
  public var debugDescription: String {
    "OperationTaskIdentifier(#\(self.number))"
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
