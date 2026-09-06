// MARK: - OperationDecorator

/// A protocol that applies modifiers to every operation run by an ``OperationRuntime``.
///
/// Conform to this protocol when a group of operations should share behavior, rather than
/// restating that behavior at every call site.
///
/// ```swift
/// struct SupervisionDecorator: OperationDecorator {
///   func decorate<Operation: OperationRequest>(
///     _ operation: Operation
///   ) -> any OperationRequest<Operation.Value, Operation.Failure> {
///     operation.retry(limit: 3)
///       .backoff(.exponential(.milliseconds(50)).jittered())
///   }
/// }
/// ```
///
/// This is a protocol rather than a closure because a closure cannot be generic over the operation
/// it decorates, and the decoration has to preserve that operation's `Value` and `Failure`.
/// ``OperationClient/StoreCreator`` takes the same shape for the same reason.
public protocol OperationDecorator: Sendable {
  /// Applies modifiers to an operation.
  ///
  /// - Parameter operation: The operation being run.
  /// - Returns: `operation` with this decorator's modifiers applied.
  func decorate<Operation: OperationRequest>(
    _ operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure>
}

// MARK: - UndecoratedOperations

/// An ``OperationDecorator`` that applies no modifiers.
public struct UndecoratedOperations: OperationDecorator {
  public init() {}

  public func decorate<Operation: OperationRequest>(
    _ operation: Operation
  ) -> any OperationRequest<Operation.Value, Operation.Failure> {
    operation
  }
}

extension OperationDecorator where Self == UndecoratedOperations {
  /// An ``OperationDecorator`` that applies no modifiers.
  public static var undecorated: Self {
    UndecoratedOperations()
  }
}

// MARK: - OperationRuntime

/// A runtime that runs any ``OperationRequest`` with a shared ``OperationContext`` and a shared
/// set of modifiers.
///
/// ``OperationRunner`` runs a single operation, and `#run` builds one with a fresh
/// ``OperationContext`` each time it is invoked. Neither is somewhere shared policy can live, so a
/// program that runs many operations restates that policy at every call site, and nothing that
/// runs in one operation is visible to the next. An `OperationRuntime` is to `OperationRunner`
/// what ``OperationClient`` is to ``OperationStore``: the place defaults are declared once.
///
/// ```swift
/// let runtime = OperationRuntime(decorator: SupervisionDecorator())
///
/// let mux = try await runtime.run($launchMux(project))
/// let endpoint = try await runtime.run($bindEndpoint(mux.port))
/// ```
///
/// Much of what looks like duplicated modifiers is duplicated *context*. ``backoff(_:)``,
/// ``delayer(_:)`` and ``clock(_:)`` only write context values, so setting them on the runtime's
/// ``context`` covers them without a decorator at all. A decorator is for modifiers that wrap a
/// run, such as ``OperationRequest/retry(limit:)``.
///
/// The runtime's modifiers are applied *around* the operation's own. Where a modifier defines what
/// happens when it is applied twice, that definition decides which one wins: an operation that
/// already carries ``OperationRequest/retry(limit:)`` keeps its own limit rather than the
/// runtime's, in the same way that an operation overrides the retry behavior an `OperationClient`
/// applies by default.
public struct OperationRuntime: Sendable {
  /// The ``OperationContext`` handed to every operation this runtime runs.
  public var context: OperationContext

  /// The ``OperationDecorator`` applied to every operation this runtime runs.
  public let decorator: any OperationDecorator

  /// Creates a runtime.
  ///
  /// - Parameters:
  ///   - context: The ``OperationContext`` to hand to every operation this runtime runs.
  ///   - decorator: The ``OperationDecorator`` to apply to every operation this runtime runs.
  public init(
    context: OperationContext = OperationContext(),
    decorator: any OperationDecorator = .undecorated
  ) {
    self.context = context
    self.decorator = decorator
  }

  /// Runs an operation.
  ///
  /// The operation is decorated, and then ``OperationRequest/setup(context:)-8y79v`` is invoked on
  /// the result with a copy of this runtime's ``context``. Setup runs per call rather than once,
  /// because a runtime runs a different operation each time.
  ///
  /// - Parameters:
  ///   - operation: The ``OperationRequest`` to run.
  ///   - isolation: The current actor-isolation of this operation run.
  ///   - continuation: An ``OperationContinuation`` that allows you to yield data while the
  ///   operation is still running. See <doc:MultistageOperations> for more.
  /// - Returns: The value returned from the operation.
  public func run<Operation: OperationRequest>(
    _ operation: Operation,
    isolation: isolated (any Actor)? = #isolation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure> =
      OperationContinuation { _, _ in }
  ) async throws(Operation.Failure) -> Operation.Value {
    let decorated = self.decorator.decorate(operation)
    var context = self.context
    decorated.setup(context: &context)
    return try await decorated.run(isolation: isolation, in: context, with: continuation)
  }
}
