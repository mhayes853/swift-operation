// MARK: - OperationResultUpdateReason

/// A reason that an operation yielded a result.
///
/// You can check the reason from within the ``OperationEventHandler/onResultReceived`` callback.
/// The callback is invoked from within the ``StatefulOperationRequest/handleEvents(with:)``
/// modifier (``OperationStore`` automatically applies this modifier to your operation).
///
/// ```swift
/// let handler = OperationEventHandler<MyQuery.State> { state, context in
///   // ...
/// } onResultReceived: { result, context in
///   guard context.operationResultUpdateReason == .returnedFinalResult else { return }
///   // Runs when `MyQuery` returns its final result...
/// }
/// ```
public struct OperationResultUpdateReason: Hashable, Sendable {
  private let rawValue: String
}

extension OperationResultUpdateReason {
  /// The operation yielded a result through an ``OperationContinuation``.
  public static let yieldedResult = Self(rawValue: "yieldedResult")

  /// The operation returned its final value from ``OperationRequest/run(isolation:in:with:)``.
  public static let returnedFinalResult = Self(rawValue: "returnedFinalResult")
}

extension OperationResultUpdateReason: CustomStringConvertible {
  public var description: String {
    self.rawValue
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The current ``OperationResultUpdateReason`` in this context.
  ///
  /// This value is non-nil when accessed from within the
  /// ``OperationEventHandler/onResultReceived`` callback.
  public var operationResultUpdateReason: OperationResultUpdateReason? {
    get { self[OperationResultUpdateReasonKey.self] }
    set { self[OperationResultUpdateReasonKey.self] = newValue }
  }

  private enum OperationResultUpdateReasonKey: Key {
    static let defaultValue: OperationResultUpdateReason? = nil
  }
}
