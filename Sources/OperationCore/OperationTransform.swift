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

// MARK: - Applying

extension [any OperationTransform] {
  func applied<Operation: OperationRequest>(
    to operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure> {
    self.reversed()
      .reduce(AnyOperation(operation)) { transformed, transform in
        AnyOperation(transform.apply(to: transformed))
      }
  }
}

// MARK: - Current Transforms

private enum CurrentOperationTransforms {
  @TaskLocal static var value = [any OperationTransform]()
}

/// The ``OperationTransform``s applied to operations run by the current task, outermost first.
///
/// ```swift
/// try await withOperationTransform(SupervisionTransform()) {
///   let transforms = operationTransforms
///   Task.detached {
///     // The transforms do not cross this boundary on their own.
///     try await withOperationTransforms(transforms) {
///       try await #run($launchMux(project))
///     }
///   }
/// }
/// ```
public var operationTransforms: [any OperationTransform] {
  CurrentOperationTransforms.value
}

/// Applies an ``OperationTransform`` to every operation run within `operation`, in addition to
/// those already in scope.
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
///
///   try await withOperationTransform(LoggingTransform()) {
///     // And this operation is logged as well
///     let endpoint = try await #run($bindEndpoint(mux.port))
///   }
/// }
/// ```
///
/// - Parameters:
///   - transform: The ``OperationTransform`` to apply.
///   - isolation: The current actor-isolation.
///   - operation: The body to apply the transform to.
/// - Returns: Whatever `operation` returns.
public func withOperationTransform<T>(
  _ transform: some OperationTransform,
  isolation: isolated (any Actor)? = #isolation,
  operation: () async throws -> T
) async rethrows -> T {
  try await withOperationTransforms(
    operationTransforms + [transform],
    isolation: isolation,
    operation: operation
  )
}

/// Applies exactly the specified ``OperationTransform``s to every operation run within
/// `operation`, replacing any already in scope.
///
/// Transforms are applied innermost last, so the final element of `transforms` ends up closest to
/// the operation.
///
/// ```swift
/// // Nothing in scope is applied within the body.
/// try await withOperationTransforms([]) {
///   let mux = try await #run($launchMux(project))
/// }
/// ```
///
/// - Parameters:
///   - transforms: The ``OperationTransform``s to apply.
///   - isolation: The current actor-isolation.
///   - operation: The body to apply the transforms to.
/// - Returns: Whatever `operation` returns.
public func withOperationTransforms<T>(
  _ transforms: some Sequence<any OperationTransform>,
  isolation: isolated (any Actor)? = #isolation,
  operation: () async throws -> T
) async rethrows -> T {
  try await CurrentOperationTransforms.$value.withValue(
    Array(transforms),
    operation: operation,
    isolation: isolation
  )
}
