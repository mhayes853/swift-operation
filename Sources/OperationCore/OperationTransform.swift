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
///
/// A transform is applied at the point of a run, which makes it the most local description of how
/// that run should behave. Its modifiers therefore win over the ones the operation was built with,
/// including the defaults an `OperationClient` applies to every store it creates.
///
/// ```swift
/// let library = client.store(for: $syncLibrary)
///
/// // Retries twice with the client's backoff.
/// try await library.fetch()
///
/// try await withOperationTransform(BackgroundSyncTransform(limit: 20)) {
///   // Retries 20 times with the transform's backoff. Same store, same operation.
///   try await library.fetch()
/// }
/// ```
///
/// > Note: A transform's modifiers are set up once per run, rather than once per operation, so a
/// > modifier that allocates state during setup gets fresh state every time. Applying
/// > ``OperationRequest/deduplicated()`` from a transform deduplicates nothing, as each run builds
/// > its own storage. Apply stateful modifiers when building the operation instead.
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

extension OperationRequest {
  func applying(
    _ transforms: [any OperationTransform]
  ) -> any OperationRequest<Value, Failure> {
    guard let innermost = transforms.last else { return self }

    // NB: The boundary stops a scoped setup pass from descending into this operation, which the
    // runtime has already set up. See `_OperationChainBoundary` for why that matters.
    let applied = innermost.apply(to: self.modifier(_OperationChainBoundary()))
    guard transforms.count > 1 else { return applied }
    return transforms.dropLast()
      .reversed()
      .reduce(AnyOperation(applied)) { transformed, transform in
        AnyOperation(transform.apply(to: transformed))
      }
  }
}

// MARK: - OperationChainBoundary

/// A modifier marking the point where an operation's own modifiers begin, and the modifiers
/// applied to it by the ``OperationTransform``s in scope end.
struct _OperationChainBoundary<Operation: OperationRequest>: OperationModifier, Sendable {
  func setup(context: inout OperationContext, using operation: Operation) {
    // NB: An `OperationRunner` sets its operation up a single time, so setting it up again on
    // every run would mint a second deduplication storage, re-append its operation controllers,
    // and re-add its stale-when-revalidate predicates. Descending would also overwrite the
    // configuration that the transforms in scope just wrote on the way back down the chain.
    guard context.modifierSetupScope != .operationRun else { return }
    operation.setup(context: &context)
  }

  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    try await operation.run(isolation: isolation, in: context, with: continuation)
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
///     // This operation is logged alongside having retries
///     let endpoint = try await #run($bindEndpoint(mux.port))
///   }
///
///   try await withOperationTransform(LoggingTransform(), behavior: .override) {
///     // This operation is only logged
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
public func withOperationTransform<T, Failure: Error>(
  _ transform: some OperationTransform,
  behavior: OperationTransformBehavior = .append,
  isolation: isolated (any Actor)? = #isolation,
  operation: () async throws(Failure) -> T
) async throws(Failure) -> T {
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
public func withOperationTransforms<T, Failure: Error>(
  _ transforms: some Sequence<any OperationTransform>,
  behavior: OperationTransformBehavior = .override,
  isolation: isolated (any Actor)? = #isolation,
  operation: () async throws(Failure) -> T
) async throws(Failure) -> T {
  let applied =
    switch behavior {
    case .append: operationTransforms + Array(transforms)
    case .override: Array(transforms)
    }
  do {
    return try await CurrentOperationTransforms.$value.withValue(
      applied,
      operation: operation,
      isolation: isolation
    )
  } catch {
    throw error as! Failure
  }
}
