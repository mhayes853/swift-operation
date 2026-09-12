// MARK: - OperationTimeoutError

/// An error indicating that an operation exceeded its timeout duration.
public struct OperationTimeoutError: Error, Hashable, Sendable {
  /// The duration after which the operation timed out.
  public let duration: OperationDuration

  /// Creates a timeout error for `duration`.
  ///
  /// - Parameter duration: The duration after which the operation timed out.
  public init(duration: OperationDuration) {
    self.duration = duration
  }
}

// MARK: - Timeout Modifier

extension OperationRequest where Self: Sendable, Value: Sendable, Failure == any Error {
  /// Cancels this operation when it does not finish within `duration`.
  ///
  /// When the timeout expires, the operation is cancelled and an ``OperationTimeoutError`` is
  /// thrown. Cancellation is cooperative, so the operation must respond to cancellation before
  /// this modifier can finish throwing the timeout error.
  ///
  /// This modifier uses ``OperationContext/operationDelayer`` to measure the timeout. You can
  /// customize that delayer with ``OperationRequest/delayer(_:)``.
  ///
  /// Modifier order determines how this timeout composes with
  /// ``OperationRequest/retry(limit:merging:)``. Applying `timeout` after `retry` gives the entire
  /// retry sequence one timeout budget. Applying `retry` after `timeout` gives each attempt its own
  /// timeout budget.
  ///
  /// - Parameter duration: The maximum duration of the operation run. A duration less than or
  ///   equal to zero times out without starting the operation.
  /// - Returns: A ``ModifiedOperation``.
  @_disfavoredOverload
  public func timeout(
    after duration: OperationDuration
  ) -> ModifiedOperation<Self, _TimeoutModifier<Self>> {
    self.timeout(after: duration, throwing: OperationTimeoutError(duration: duration))
  }

  /// Cancels this operation when it does not finish within `duration`.
  ///
  /// When the timeout expires, the operation is cancelled and an ``OperationTimeoutError`` is
  /// thrown. Cancellation is cooperative, so the operation must respond to cancellation before
  /// this modifier can finish throwing the timeout error.
  ///
  /// This modifier uses ``OperationContext/operationDelayer`` to measure the timeout. You can
  /// customize that delayer with ``OperationRequest/delayer(_:)``.
  ///
  /// Modifier order determines how this timeout composes with
  /// ``OperationRequest/retry(limit:merging:)``. Applying `timeout` after `retry` gives the entire
  /// retry sequence one timeout budget. Applying `retry` after `timeout` gives each attempt its own
  /// timeout budget.
  ///
  /// - Parameter duration: The maximum duration of the operation run. A duration less than or
  ///   equal to zero times out without starting the operation.
  /// - Returns: A ``ModifiedOperation``.
  @available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
  public func timeout(
    after duration: Duration
  ) -> ModifiedOperation<Self, _TimeoutModifier<Self>> {
    self.timeout(after: OperationDuration(duration: duration))
  }
}

extension OperationRequest where Self: Sendable, Value: Sendable {
  /// Cancels this operation with `error` when it does not finish within `duration`.
  ///
  /// Use this overload when the operation has a concrete failure type. The supplied error keeps
  /// the operation's failure type unchanged, allowing stateful operation conformances to be
  /// preserved.
  ///
  /// Cancellation is cooperative, so the operation must respond to cancellation before this
  /// modifier can finish throwing the timeout error. This modifier uses
  /// ``OperationContext/operationDelayer`` to measure the timeout.
  ///
  /// Modifier order determines how this timeout composes with
  /// ``OperationRequest/retry(limit:merging:)``. Applying `timeout` after `retry` gives the entire
  /// retry sequence one timeout budget. Applying `retry` after `timeout` gives each attempt its own
  /// timeout budget.
  ///
  /// - Parameters:
  ///   - duration: The maximum duration of the operation run. A duration less than or equal to zero
  ///     times out without starting the operation.
  ///   - error: The error to throw when the timeout expires.
  /// - Returns: A ``ModifiedOperation``.
  @_disfavoredOverload
  public func timeout(
    after duration: OperationDuration,
    throwing error: @autoclosure @escaping @Sendable () -> Failure
  ) -> ModifiedOperation<Self, _TimeoutModifier<Self>> {
    self.modifier(_TimeoutModifier(duration: duration, timeoutError: error))
  }

  /// Cancels this operation with `error` when it does not finish within `duration`.
  ///
  /// Use this overload when the operation has a concrete failure type. The supplied error keeps
  /// the operation's failure type unchanged, allowing stateful operation conformances to be
  /// preserved.
  ///
  /// Cancellation is cooperative, so the operation must respond to cancellation before this
  /// modifier can finish throwing the timeout error. This modifier uses
  /// ``OperationContext/operationDelayer`` to measure the timeout.
  ///
  /// Modifier order determines how this timeout composes with
  /// ``OperationRequest/retry(limit:merging:)``. Applying `timeout` after `retry` gives the entire
  /// retry sequence one timeout budget. Applying `retry` after `timeout` gives each attempt its own
  /// timeout budget.
  ///
  /// - Parameters:
  ///   - duration: The maximum duration of the operation run. A duration less than or equal to zero
  ///     times out without starting the operation.
  ///   - error: The error to throw when the timeout expires.
  /// - Returns: A ``ModifiedOperation``.
  @available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
  public func timeout(
    after duration: Duration,
    throwing error: @autoclosure @escaping @Sendable () -> Failure
  ) -> ModifiedOperation<Self, _TimeoutModifier<Self>> {
    self.timeout(after: OperationDuration(duration: duration), throwing: error())
  }
}

public struct _TimeoutModifier<Operation: OperationRequest & Sendable>: OperationModifier, Sendable
where Operation.Value: Sendable {
  let duration: OperationDuration
  let timeoutError: @Sendable () -> Operation.Failure

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    guard self.duration > .zero else { throw self.timeoutError() }

    let result = await withTaskGroup(
      of: _TimeoutRaceResult<Operation.Value, Operation.Failure>.self,
      returning: Result<Operation.Value, Operation.Failure>.self
    ) { group in
      group.addTask {
        .operation(
          await self.run(
            operation,
            isolation: isolation,
            in: context,
            with: continuation
          )
        )
      }
      group.addTask {
        do {
          try await context.operationDelayer.delay(for: self.duration)
          try Task.checkCancellation()
          return .timedOut
        } catch {
          return .timerFailed(error)
        }
      }

      while let result = await group.next() {
        switch result {
        case .operation(let result):
          group.cancelAll()
          return result
        case .timedOut:
          group.cancelAll()
          return .failure(self.timeoutError())
        case .timerFailed(let error):
          guard let error = error as? Operation.Failure else { continue }
          group.cancelAll()
          return .failure(error)
        }
      }
      fatalError("A timeout race must contain an operation task.")
    }
    return try result.get()
  }

  private func run(
    _ operation: Operation,
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async -> Result<Operation.Value, Operation.Failure> {
    do {
      return .success(
        try await operation.run(isolation: isolation, in: context, with: continuation)
      )
    } catch {
      return .failure(error)
    }
  }
}

private enum _TimeoutRaceResult<Value: Sendable, Failure: Error>: Sendable {
  case operation(Result<Value, Failure>)
  case timedOut
  case timerFailed(any Error)
}
