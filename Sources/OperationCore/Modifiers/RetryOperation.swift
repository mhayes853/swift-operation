// MARK: - RetryModifier

extension OperationRequest {
  /// Applies a retrying to this operation.
  ///
  /// A retry is performed when this operation throws an error. If this operation never throws an
  /// error, then this modifier has no effect.
  ///
  /// This modifier uses the ``OperationContext/operationDelayer`` and
  /// ``OperationContext/operationBackoffFunction`` to control the timing strategy of the retries
  /// of this operation. The default timing strategy is to use exponential backoff with a base
  /// delay of 1 second. You can customize the manner in which delays are performed via the
  /// ``OperationRequest/delayer(_:)`` and ``OperationRequest/backoff(_:)`` modifiers respectively.
  ///
  /// In order to preserve the existing <doc:/documentation/OperationCore/OperationRequest/Failure>
  /// type of this operation, if the underlying task of this operation is cancelled, a
  /// cancellation error will not be thrown. To preserve cancellation, ensure that this operation
  /// supports cooperative cancellation, and avoid doing any irreversible synchronous work before
  /// reaching a suspension point in this operation.
  ///
  /// - Parameters:
  ///   - limit: The maximum number of retries.
  /// - Returns: A ``ModifiedOperation``.
  public func retry(limit: Int) -> ModifiedOperation<Self, _RetryModifier<Self>> {
    self.modifier(_RetryModifier(limit: limit))
  }
}

public struct _RetryModifier<Operation: OperationRequest>: OperationModifier, Sendable {
  let limit: Int

  public func setup(context: inout OperationContext, using operation: Operation) {
    context.operationMaxRetries = self.limit
    operation.setup(context: &context)
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    var context = context
    for index in 0..<context.operationMaxRetries {
      do {
        context.operationRetryIndex = index == 0 ? nil : index - 1
        return try await operation.run(isolation: isolation, in: context, with: continuation)
      } catch {
        try? await context.operationDelayer.delay(for: context.operationBackoffFunction(index + 1))
      }
    }
    context.operationRetryIndex =
      context.operationMaxRetries > 0 ? context.operationMaxRetries - 1 : nil
    return try await operation.run(isolation: isolation, in: context, with: continuation)
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The current retry attempt for the current operation run.
  ///
  /// This value starts at 0, but increments every time the ``OperationRequest/retry(limit:)``
  /// modifier retries an operation run. An index value of nil indicates that the operation run is
  /// currently on its first attempt, and has not been retried yet.
  public var operationRetryIndex: Int? {
    get { self[RetryIndexKey.self] }
    set { self[RetryIndexKey.self] = newValue }
  }

  private enum RetryIndexKey: Key {
    static let defaultValue: Int? = nil
  }

  /// The maximum number of retries for an operation run.
  ///
  /// The default value of this context property is 0. However, using
  /// ``OperationRequest/retry(limit:)`` will set this value to the `limit` parameter.
  public var operationMaxRetries: Int {
    get { self[MaxRetriesKey.self] }
    set { self[MaxRetriesKey.self] = newValue }
  }

  private enum MaxRetriesKey: Key {
    static let defaultValue = 0
  }

  /// Whether or not the operation run is on its last retry attempt.
  public var isLastRetryAttempt: Bool {
    self.operationRetryIndex == self.operationMaxRetries - 1
  }

  /// Whether or not the operation run is on its first retry attempt.
  public var isFirstRetryAttempt: Bool {
    self.operationRetryIndex == 0
  }

  /// Whether or not the operation run is on its initial attempt.
  ///
  /// This value is true when the operation run is being attempted for the first time, and has not
  /// been retried due to throwing an error. If you want to check if the operation run is being
  /// retried for the first time, use ``isFirstRetryAttempt``.
  public var isFirstRunAttempt: Bool {
    self.operationRetryIndex == nil
  }

  /// Whether or not the operation run is on its final attempt.
  ///
  /// When this value is true, the operation run will no longer be retried if it throws an error.
  ///
  /// You can check this property as an indicator of when you should try to fetch data with a
  /// minimal chance of an error being thrown. For instance, you could fetch data stored locally on
  /// disk rather than from your server, as loading from disk isn't as error prone as fetching data
  /// from over the network, in order to implement offline support.
  public var isLastRunAttempt: Bool {
    (self.isFirstRunAttempt && self.operationMaxRetries == 0) || self.isLastRetryAttempt
  }
}
