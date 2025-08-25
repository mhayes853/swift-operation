// MARK: - QueryResultUpdateReason

/// A reason that a query yielded a result.
///
/// You can check the reason from within the ``QueryEventHandler/onResultReceived`` callback.
///
/// ```swift
/// let handler = QueryEventHandler<MyQuery.State> { state, context in
///   // ...
/// } onResultReceived: { result, context in
///   guard context.operationResultUpdateReason == .returnedFinalResult else { return }
///   // ...
/// }
/// ```
public struct OperationResultUpdateReason: Hashable, Sendable {
  private let rawValue: String
}

extension OperationResultUpdateReason {
  /// The query yielded a result through a ``OperationContinuation``.
  public static let yieldedResult = Self(rawValue: "yieldedResult")

  /// The query returned its final value from ``QueryRequest/fetch(in:with:)``.
  public static let returnedFinalResult = Self(rawValue: "returnedFinalResult")
}

extension OperationResultUpdateReason: CustomStringConvertible {
  public var description: String {
    self.rawValue
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The current ``QueryResultUpdateReason`` in this context.
  ///
  /// This value is non-nil when accessed from within the ``QueryEventHandler/onResultReceived``
  /// callback.
  public var operationResultUpdateReason: OperationResultUpdateReason? {
    get { self[OperationResultUpdateReasonKey.self] }
    set { self[OperationResultUpdateReasonKey.self] = newValue }
  }

  private enum OperationResultUpdateReasonKey: Key {
    static let defaultValue: OperationResultUpdateReason? = nil
  }
}
