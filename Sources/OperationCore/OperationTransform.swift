// MARK: - OperationTransform

/// A set of modifiers applied to every operation run within a scope.
///
/// Operations that share behavior usually restate it at every call site. A transform states it
/// once, and ``withOperationTransform(_:isolation:operation:)`` decides where it applies.
///
/// ```swift
/// struct SupervisionTransform: OperationTransform {
///   func apply<Operation: OperationRequest>(
///     to operation: Operation
///   ) -> any OperationRequest<Operation.Value, Operation.Failure> {
///     operation.retry(limit: 3)
///       .backoff(.exponential(.milliseconds(50)).jittered())
///   }
/// }
///
/// try await withOperationTransform(SupervisionTransform()) {
///   let mux = try await #run($launchMux(project))
///   let endpoint = try await #run($bindEndpoint(mux.port))
/// }
/// ```
///
/// This is a protocol rather than a closure because a closure cannot be generic over the operation
/// it is applied to, and the result has to preserve that operation's `Value` and `Failure`.
/// ``OperationClient/StoreCreator`` takes the same shape for the same reason.
///
/// A transform's modifiers wrap the operation's own. Any modifier that defines what happens when
/// it is applied twice therefore decides which one wins: an operation carrying
/// ``OperationRequest/retry(limit:)`` keeps its own limit rather than the transform's, in the same
/// way that an operation overrides the retry behavior an ``OperationClient`` applies by default.
public protocol OperationTransform: Sendable {
  /// Applies this transform's modifiers to an operation.
  ///
  /// This method is called once per run, and must be free of side effects. Modifiers are allowed
  /// to carry per-instance identity — ``OperationRequest/retry(limit:)`` does, to detect being
  /// applied twice — so applying a transform is not something the library can safely do more than
  /// once for the same run.
  ///
  /// - Parameter operation: The operation being run.
  /// - Returns: `operation` with this transform's modifiers applied.
  func apply<Operation: OperationRequest>(
    to operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure>
}

// MARK: - Current Transform

private enum CurrentOperationTransform {
  @TaskLocal static var value: (any OperationTransform)?
}

/// The ``OperationTransform`` applied to operations run by the current task, or nil when no
/// transform is in scope.
///
/// Read this to compose a transform with the one already in scope, rather than replacing it.
///
/// ```swift
/// struct LoggingTransform: OperationTransform {
///   let base: (any OperationTransform)?
///
///   func apply<Operation: OperationRequest>(
///     to operation: Operation
///   ) -> any OperationRequest<Operation.Value, Operation.Failure> {
///     let operation = self.base?.apply(to: operation) ?? operation
///     return operation.logDuration()
///   }
/// }
///
/// try await withOperationTransform(LoggingTransform(base: currentOperationTransform)) {
///   // ...
/// }
/// ```
public var currentOperationTransform: (any OperationTransform)? {
  CurrentOperationTransform.value
}

/// Applies an ``OperationTransform`` to every operation run within `operation`.
///
/// The transform reaches every operation run in the body, including ones run by child tasks,
/// without being threaded through the code between. Operations run outside the body are
/// unaffected.
///
/// A nested call replaces the transform for its own body rather than composing with it. Read
/// ``currentOperationTransform`` to compose deliberately.
///
/// - Parameters:
///   - transform: The ``OperationTransform`` to apply.
///   - isolation: The current actor-isolation.
///   - operation: The body to run the transform for.
/// - Returns: Whatever `operation` returns.
public func withOperationTransform<T>(
  _ transform: some OperationTransform,
  isolation: isolated (any Actor)? = #isolation,
  operation: () async throws -> T
) async rethrows -> T {
  try await CurrentOperationTransform.$value.withValue(
    transform,
    operation: operation,
    isolation: isolation
  )
}
