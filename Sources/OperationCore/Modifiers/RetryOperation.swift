// MARK: - OperationRetryCondition

/// A condition that determines whether or not an operation is retried after it throws an error.
///
/// A retry condition pairs an optional upper bound on the number of retries, which is published to
/// ``OperationContext/operationMaxRetries``, with a predicate that inspects the thrown error. Both
/// must permit a retry in order for one to occur.
///
/// The bound is kept separate from the predicate rather than being folded into it because it must
/// be known _before_ an attempt runs in order to power ``OperationContext/isKnownLastRunAttempt``.
/// The predicate, in contrast, can only be evaluated _after_ an attempt has failed, as it requires
/// the error.
///
/// Conditions are combined using ``&&(_:_:)`` and ``||(_:_:)``.
///
/// ```swift
/// let condition = OperationRetryCondition.maxRetries(3)
///   && OperationRetryCondition { error, _ in !(error is AuthenticationError) }
/// ```
public struct OperationRetryCondition: Sendable {
  /// The upper bound this condition places on the number of retries, if it places one.
  ///
  /// A nil value indicates that this condition is unbounded, and permits retries for as long as its
  /// predicate does.
  public var maxRetries: Int?

  private let predicate: @Sendable (any Error, OperationContext) async -> Bool

  /// Creates a bounded retry condition from a predicate you specify.
  ///
  /// - Parameters:
  ///   - maxRetries: The maximum number of retry attempts for this predicate.
  ///   - predicate: A predicate that decides whether or not the thrown error warrants a retry.
  public init(
    maxRetries: Int? = nil,
    _ predicate: @escaping @Sendable (any Error, OperationContext) async -> Bool
  ) {
    self.maxRetries = maxRetries
    self.predicate = predicate
  }

  /// Evaluates this condition with the specified `error` and `context`.
  ///
  /// A retry is permitted only when the retries performed so far are within ``maxRetries``, and
  /// this condition's predicate permits one. The predicate is not evaluated when the bound has
  /// already been reached.
  ///
  /// - Parameters:
  ///   - error: The error thrown by an operation attempt.
  ///   - context: The context from that operation attempt.
  /// - Returns: Whether or not to perform another retry.
  public func evaluate(error: some Error, in context: OperationContext) async -> Bool {
    guard context.performedRetries < self.maxRetries ?? .max else { return false }
    return await self.predicate(error, context)
  }
}

// MARK: - Conditions

extension OperationRetryCondition {
  /// A condition that permits at most `limit` retries, regardless of the error thrown.
  ///
  /// - Parameter limit: The maximum number of retries.
  /// - Returns: A retry condition.
  public static func maxRetries(_ limit: Int) -> Self {
    Self(maxRetries: limit) { _, _ in true }
  }

  /// A condition that never permits a retry.
  public static let never = Self(maxRetries: 0) { _, _ in false }
}

// MARK: - Combining

extension OperationRetryCondition {
  /// Combines 2 retry conditions such that both must permit a retry in order for one to occur.
  ///
  /// The resulting condition is bounded by the smaller of the 2 bounds, and its predicate is the
  /// boolean AND of both predicates. `rhs`'s predicate is not evaluated when `lhs`'s predicate
  /// returns false.
  ///
  /// - Parameters:
  ///   - lhs: A retry condition.
  ///   - rhs: A retry condition.
  /// - Returns: A retry condition permitting a retry only when both `lhs` and `rhs` permit one.
  public static func && (lhs: Self, rhs: Self) -> Self {
    var condition = Self { error, context in
      guard await lhs.predicate(error, context) else { return false }
      return await rhs.predicate(error, context)
    }
    condition.maxRetries = lhs.combinedMaxRetries(with: rhs)
    return condition
  }

  /// Combines 2 retry conditions such that either one permitting a retry is enough for one to
  /// occur.
  ///
  /// The resulting condition is bounded by the larger of the 2 bounds, and is unbounded if either
  /// operand is unbounded. `rhs`'s predicate is not evaluated when `lhs`'s predicate returns true.
  ///
  /// > Note: Since ``maxRetries(_:)`` carries a predicate that always permits a retry, using it as
  /// > an operand here makes the combined predicate always permit one too. Impose bounds with
  /// > ``&&(_:_:)`` on the outside instead.
  ///
  /// - Parameters:
  ///   - lhs: A retry condition.
  ///   - rhs: A retry condition.
  /// - Returns: A retry condition permitting a retry when either `lhs` or `rhs` permits one.
  public static func || (lhs: Self, rhs: Self) -> Self {
    var condition = Self { error, context in
      guard await lhs.predicate(error, context) else {
        return await rhs.predicate(error, context)
      }
      return true
    }
    condition.maxRetries = lhs.unionMaxRetries(with: rhs)
    return condition
  }

  private func combinedMaxRetries(with other: Self) -> Int? {
    switch (self.maxRetries, other.maxRetries) {
    case let (lhs?, rhs?): min(lhs, rhs)
    case let (lhs?, nil): lhs
    case let (nil, rhs?): rhs
    case (nil, nil): nil
    }
  }

  private func unionMaxRetries(with other: Self) -> Int? {
    guard let lhs = self.maxRetries, let rhs = other.maxRetries else { return nil }
    return max(lhs, rhs)
  }
}

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
  /// When multiple retry modifiers are applied to an operation, only the first one applied will
  /// have any effect. This is to allow you to override the default retry behavior applied by the
  /// default initializer of ``OperationClient``.
  ///
  /// ```swift
  /// // The operation retry limit is 5, and the second retry modifier
  /// // has no effect on `operation`.
  /// let operation = $myOperation
  ///   .retry(limit: 5)
  ///   .retry(limit: 3)
  /// ```
  ///
  /// A retry modifier applied by an ``OperationTransform`` in scope for a run is the exception to
  /// that rule, which lets you dial an operation's persistence up or down for a particular piece of
  /// work. The transform states the limit, and its predicate is OR'd with the operation's own.
  ///
  /// ```swift
  /// struct BackgroundSyncTransform: OperationTransform {
  ///   let limit: Int
  ///
  ///   func apply<Operation: OperationRequest>(
  ///     to operation: Operation
  ///   ) -> any OperationRequest<Operation.Value, Operation.Failure> {
  ///     operation.retry(limit: self.limit)
  ///   }
  /// }
  ///
  /// let store = client.store(for: $syncLibrary)
  ///
  /// // Uses default retry limit applied by the client.
  /// try await store.fetch()
  ///
  /// try await withOperationTransform(BackgroundSyncTransform(limit: 20)) {
  ///   // Uses 20 for the retry limit
  ///   try await store.fetch()
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - limit: The maximum number of retries.
  /// - Returns: A ``ModifiedOperation``.
  public func retry(limit: Int) -> ModifiedOperation<Self, _RetryModifier<Self>> {
    self.retry(.maxRetries(limit))
  }

  /// Applies a retrying to this operation that is limited both by a maximum number of retries, and
  /// by a predicate on the thrown error.
  ///
  /// A retry is performed when this operation throws an error, `predicate` returns true for that
  /// error, and fewer than `limit` retries have been performed. `predicate` is evaluated _before_
  /// any backoff is applied, so an error that does not warrant a retry fails the operation
  /// immediately rather than after a delay.
  ///
  ///
  /// ```swift
  /// // Retries up to 3 times, but never burns a retry on an authentication failure.
  /// let operation = $myOperation.retry(limit: 3) { error, _ in
  ///   !(error is AuthenticationError)
  /// }
  /// ```
  ///
  /// See ``OperationRequest/retry(limit:)`` for details on backoff, cancellation, and the behavior
  /// of applying multiple retry modifiers to a single operation.
  ///
  /// - Parameters:
  ///   - limit: The maximum number of retries.
  ///   - predicate: A predicate that decides whether or not the thrown error warrants a retry.
  /// - Returns: A ``ModifiedOperation``.
  public func retry(
    limit: Int,
    when predicate: @escaping @Sendable (Failure, OperationContext) async -> Bool
  ) -> ModifiedOperation<Self, _RetryModifier<Self>> {
    self.retry(.maxRetries(limit) && self.retryCondition(from: predicate))
  }

  /// Applies an unbounded retrying to this operation that is limited only by a predicate on the
  /// thrown error.
  ///
  /// A retry is performed whenever this operation throws an error for which `predicate` returns
  /// true. `predicate` is evaluated _before_ any backoff is applied, so an error that does not
  /// warrant a retry fails the operation immediately rather than after a delay.
  ///
  /// > Important: This modifier places no upper bound on the number of retries. An operation that
  /// > repeatedly throws errors for which `predicate` returns true will be retried indefinitely.
  /// > Use ``OperationRequest/retry(limit:when:)`` if you want to impose a bound. Without one,
  /// > ``OperationContext/operationMaxRetries`` reads as `Int.max` and
  /// > ``OperationContext/isKnownLastRunAttempt`` is always false.
  ///
  /// See ``OperationRequest/retry(limit:)`` for details on backoff, cancellation, and the behavior
  /// of applying multiple retry modifiers to a single operation.
  ///
  /// - Parameter predicate: A predicate that decides whether or not the thrown error warrants a
  ///   retry.
  /// - Returns: A ``ModifiedOperation``.
  public func retry(
    when predicate: @escaping @Sendable (Failure, OperationContext) async -> Bool
  ) -> ModifiedOperation<Self, _RetryModifier<Self>> {
    self.retry(self.retryCondition(from: predicate))
  }

  /// Applies a retrying to this operation using an ``OperationRetryCondition``.
  ///
  /// See ``OperationRequest/retry(limit:)`` for details on backoff, cancellation, and the behavior
  /// of applying multiple retry modifiers to a single operation.
  ///
  /// - Parameter condition: The condition under which this operation is retried.
  /// - Returns: A ``ModifiedOperation``.
  public func retry(
    _ condition: OperationRetryCondition
  ) -> ModifiedOperation<Self, _RetryModifier<Self>> {
    self.modifier(_RetryModifier(condition: condition))
  }

  private func retryCondition(
    from predicate: @escaping @Sendable (Failure, OperationContext) async -> Bool
  ) -> OperationRetryCondition {
    OperationRetryCondition { error, context in
      guard let error = error as? Failure else { return true }
      return await predicate(error, context)
    }
  }
}

public struct _RetryModifier<Operation: OperationRequest>: OperationModifier, Sendable {
  let condition: OperationRetryCondition
  private let retryerId = RetryerID()

  init(condition: OperationRetryCondition) {
    self.condition = condition
  }

  public func setup(context: inout OperationContext, using operation: Operation) {
    switch context.modifierSetupScope {
    case .runtimeInitialSetup:
      context.operationRetryCondition = self.condition
      context[RetryerIDKey.self] = self.retryerId
    case .operationRun:
      var condition = self.condition || context.operationRetryCondition
      condition.maxRetries = self.condition.maxRetries
      context.operationRetryCondition = condition

      if context[RetryerIDKey.self] == nil {
        context[RetryerIDKey.self] = self.retryerId
      }
    }
    operation.setup(context: &context)
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    guard context[RetryerIDKey.self] === self.retryerId else {
      return try await operation.run(isolation: isolation, in: context, with: continuation)
    }

    var context = context
    var retryIndex: Int?
    while true {
      context.operationRetryIndex = retryIndex
      do {
        return try await operation.run(isolation: isolation, in: context, with: continuation)
      } catch {
        // NB: A cancelled task would otherwise burn through every remaining attempt back to back,
        // since the delay below cannot suspend once cancelled.
        guard !Task.isCancelled else { throw error }

        guard await context.operationRetryCondition.evaluate(error: error, in: context) else {
          throw error
        }
        let performedRetries = context.performedRetries
        try? await context.operationDelayer
          .delay(for: context.operationBackoffFunction(performedRetries + 1))
        retryIndex = performedRetries
      }
    }
  }
}

// MARK: - RetryerID

private final class RetryerID: Sendable {}

private enum RetryerIDKey: OperationContext.Key {
  static var defaultValue: RetryerID? { nil }
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

  var performedRetries: Int {
    self.operationRetryIndex.map { $0 + 1 } ?? 0
  }

  /// The ``OperationRetryCondition`` for an operation run.
  ///
  /// The default value of this context property permits no retries. Applying any of the
  /// `retry` modifiers will set this value to the condition that modifier was built from.
  ///
  /// The retry loop reads this property on each attempt, and is always the innermost one in the
  /// operation. A retry modifier applied by an ``OperationTransform`` steers that loop rather than
  /// adding one of its own.
  public var operationRetryCondition: OperationRetryCondition {
    get { self[RetryConditionKey.self] }
    set { self[RetryConditionKey.self] = newValue }
  }

  private enum RetryConditionKey: Key {
    static var defaultValue: OperationRetryCondition { .maxRetries(0) }
  }

  /// The maximum number of retries for an operation run.
  ///
  /// This value is the upper bound imposed by ``operationRetryCondition``, and defaults to 0. Using
  /// ``OperationRequest/retry(limit:)`` sets it to the `limit` parameter. A condition need not
  /// impose a bound at all, such as the one created by ``OperationRequest/retry(when:)``, in which
  /// case this property reads as `Int.max`.
  public var operationMaxRetries: Int {
    get { self.operationRetryCondition.maxRetries ?? .max }
    set { self.operationRetryCondition.maxRetries = newValue }
  }

  @available(*, deprecated, renamed: "isKnownLastRetryAttempt")
  public var isLastRetryAttempt: Bool {
    self.isKnownLastRetryAttempt
  }

  /// Whether or not the operation run is known to be on its last retry attempt.
  ///
  /// This value is only ever true when ``operationRetryCondition`` imposes an upper bound on the
  /// number of retries. When it does not, the run's last retry attempt cannot be identified in
  /// advance, and this value is always false.
  public var isKnownLastRetryAttempt: Bool {
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

  @available(*, deprecated, renamed: "isKnownLastRunAttempt")
  public var isLastRunAttempt: Bool {
    self.isKnownLastRunAttempt
  }

  /// Whether or not the operation run is known to be on its final attempt.
  ///
  /// When this value is true, the operation run will no longer be retried if it throws an error.
  /// The converse does not hold. A false value means only that the final attempt cannot be
  /// identified from the retry count alone, which is the case when ``operationRetryCondition``
  /// imposes no upper bound, or when its predicate declines a retry for an error that has not been
  /// thrown yet.
  ///
  /// You can check this property from within a `catch` block as an indicator of when you should try
  /// to recover from an error with a minimal chance of another error being thrown. For instance,
  /// you could load data stored locally on disk rather than fetching it from your server in order
  /// to implement offline support.
  public var isKnownLastRunAttempt: Bool {
    (self.isFirstRunAttempt && self.operationMaxRetries == 0) || self.isKnownLastRetryAttempt
  }
}
