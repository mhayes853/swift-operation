// MARK: - OperationTransform

/// A set of modifiers applied to every operation run within a scope.
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
///   // Each operation has 3 retries and exponential backoff with jitter
///   let mux = try await #run($launchMux(project))
///   let endpoint = try await #run($bindEndpoint(mux.port))
/// }
/// ```
public protocol OperationTransform: Sendable {
  /// Applies this transform's modifiers to an operation.
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
///   // Each operation has 3 retries and exponential backoff with jitter
///   let mux = try await #run($launchMux(project))
///   let endpoint = try await #run($bindEndpoint(mux.port))
/// }
/// ```
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
