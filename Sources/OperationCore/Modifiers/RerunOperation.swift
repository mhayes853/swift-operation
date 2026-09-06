import Foundation

// MARK: - RerunModifier

extension OperationRequest {
  /// Reruns this operation while its value is unsatisfactory, for up to a specified duration.
  ///
  /// ``OperationRequest/retry(limit:)`` reruns an operation that *failed*, a fixed number of
  /// times. This modifier reruns an operation that *succeeded with a value worth asking about
  /// again*, until a deadline. Waiting for something to become true is the common case: a port
  /// that will start answering, a lock that will become free, a process that will exit. None of
  /// those are errors while they are still pending, and none of them are bounded by an attempt
  /// count, because with backoff a count of attempts says nothing about how long the wait lasts.
  ///
  /// ```swift
  /// let isReady = try await #run(
  ///   $serverIsListening(port: port)
  ///     .rerun(while: { !$0 }, for: .seconds(30))
  ///     .backoff(.exponential(.milliseconds(50)))
  /// )
  /// ```
  ///
  /// The operation always runs at least once, however short the duration. If the duration elapses
  /// while the value is still unsatisfactory, the last value is returned rather than an error
  /// being thrown, so that the caller can report the timeout in its own terms. A run that throws
  /// is not rerun, and the error is rethrown immediately: rerunning is only worth doing while the
  /// awaited state is still possible.
  ///
  /// The delay between runs comes from ``OperationContext/operationBackoffFunction`` and
  /// ``OperationContext/operationDelayer``, as it does for retries. The final delay is clamped to
  /// whatever remains of the duration, so the last run happens at the deadline rather than past
  /// it.
  ///
  /// - Parameters:
  ///   - shouldRerun: Whether a value is worth running the operation again for.
  ///   - duration: How long to keep rerunning the operation for.
  /// - Returns: A ``ModifiedOperation``.
  public func rerun(
    while shouldRerun: @escaping @Sendable (Value) -> Bool,
    for duration: OperationDuration
  ) -> ModifiedOperation<Self, _RerunModifier<Self>> {
    self.modifier(_RerunModifier(shouldRerun: shouldRerun, duration: duration))
  }
}

public struct _RerunModifier<Operation: OperationRequest>: OperationModifier, Sendable {
  let shouldRerun: @Sendable (Operation.Value) -> Bool
  let duration: OperationDuration

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    let clock = context.operationClock
    let start = clock.now()
    var rerunCount = 0
    while true {
      let value = try await operation.run(isolation: isolation, in: context, with: continuation)
      guard self.shouldRerun(value) else { return value }
      let elapsed = OperationDuration.seconds(clock.now().timeIntervalSince(start))
      let remaining = self.duration - elapsed
      guard remaining > .zero else { return value }
      rerunCount += 1
      let backoff = context.operationBackoffFunction(rerunCount)
      // A cancelled delay is swallowed rather than thrown, because the operation's Failure type
      // has no room for a cancellation error. Returning on cancellation is what keeps that from
      // becoming a loop that spins until the deadline.
      try? await context.operationDelayer.delay(for: min(backoff, remaining))
      guard !Task.isCancelled else { return value }
    }
  }
}
