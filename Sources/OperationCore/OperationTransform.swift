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

// MARK: - Behavior

/// How a scope's ``OperationTransform``s combine with the ones already in scope.
public enum OperationTransformBehavior: Hashable, Sendable {
  /// Adds to the transforms already in scope.
  case append

  /// Replaces the transforms already in scope.
  case override
}

// MARK: - Scoping

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
///
///   try await withOperationTransform(LoggingTransform()) {
///     // And this operation is logged as well
///     let endpoint = try await #run($bindEndpoint(mux.port))
///   }
///
///   try await withOperationTransform(LoggingTransform(), behavior: .override) {
///     // Whilst this operation is only logged
///     let status = try await #run($muxStatus(mux.port))
///   }
/// }
/// ```
///
/// - Parameters:
///   - transform: The ``OperationTransform`` to apply.
///   - behavior: Whether `transform` adds to the transforms in scope, or replaces them.
///   - isolation: The current actor-isolation.
///   - operation: The body to apply the transform to.
/// - Returns: Whatever `operation` returns.
public func withOperationTransform<T>(
  _ transform: some OperationTransform,
  behavior: OperationTransformBehavior = .append,
  isolation: isolated (any Actor)? = #isolation,
  operation: () async throws -> T
) async rethrows -> T {
  try await withOperationTransforms(
    [transform],
    behavior: behavior,
    isolation: isolation,
    operation: operation
  )
}

/// Applies ``OperationTransform``s to every operation run within `operation`.
///
/// Transforms are applied innermost last, so the final element of `transforms` ends up closest to
/// the operation.
///
/// ```swift
/// // The transforms in scope do not cross this boundary on their own.
/// let transforms = operationTransforms
/// Task.detached {
///   try await withOperationTransforms(transforms) {
///     try await #run($launchMux(project))
///   }
/// }
///
/// // Nothing in scope is applied within the body.
/// try await withOperationTransforms([]) {
///   let mux = try await #run($launchMux(project))
/// }
/// ```
///
/// - Parameters:
///   - transforms: The ``OperationTransform``s to apply.
///   - behavior: Whether `transforms` add to the transforms in scope, or replace them.
///   - isolation: The current actor-isolation.
///   - operation: The body to apply the transforms to.
/// - Returns: Whatever `operation` returns.
public func withOperationTransforms<T>(
  _ transforms: some Sequence<any OperationTransform>,
  behavior: OperationTransformBehavior = .override,
  isolation: isolated (any Actor)? = #isolation,
  operation: () async throws -> T
) async rethrows -> T {
  let applied =
    switch behavior {
    case .append: operationTransforms + Array(transforms)
    case .override: Array(transforms)
    }
  return try await CurrentOperationTransforms.$value.withValue(
    applied,
    operation: operation,
    isolation: isolation
  )
}
