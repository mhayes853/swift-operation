// MARK: - InlineOperation

/// An ``OperationRequest`` defined by a closure.
///
/// Operations are usually declared with the `@OperationRequest` macro, or by conforming a type to
/// ``OperationRequest`` directly. Neither is available to work that closes over local state, such
/// as a process handle or a file descriptor that only exists inside the function performing the
/// work. An inline operation describes that work as a value, so that it composes with modifiers
/// like any other operation.
///
/// ```swift
/// let process = try launchServer()
/// let didStart = try await #run(
///   InlineOperation("server readiness") { _ in await isListening(on: port) }
///     .rerun(while: { !$0 }, for: .seconds(30))
/// )
/// ```
///
/// An inline operation is deliberately not a ``StatefulOperationRequest``, so it cannot be held by
/// an ``OperationStore``. A store identifies its operation by ``OperationPath``, and two closures
/// have no useful notion of equality for a path to be derived from. Inline operations are for the
/// ``OperationRunner`` and `#run` path, where an operation is run once and its result returned.
public struct InlineOperation<Value, Failure: Error>: OperationRequest, Sendable {
  public typealias Run =
    @Sendable (
      OperationContext,
      OperationContinuation<Value, Failure>
    ) async throws(Failure) -> Value

  private let debugName: String?
  private let _run: Run

  /// Creates an inline operation.
  ///
  /// - Parameters:
  ///   - debugName: A name for this operation, reported by ``OperationRequest/_debugTypeName``.
  ///     Modifiers that log or record operations use that name, and the type name of a closure
  ///     backed operation says nothing about what it does.
  ///   - run: The work this operation performs. See <doc:MultistageOperations> for what the
  ///     ``OperationContinuation`` handed to it is for.
  public init(_ debugName: String? = nil, run: @escaping Run) {
    self.debugName = debugName
    self._run = run
  }

  /// Creates an inline operation that returns a single result.
  ///
  /// - Parameters:
  ///   - debugName: A name for this operation, reported by ``OperationRequest/_debugTypeName``.
  ///   - run: The work this operation performs.
  public init(
    _ debugName: String? = nil,
    run: @escaping @Sendable (OperationContext) async throws(Failure) -> Value
  ) {
    self.init(debugName) { context, _ throws(Failure) in try await run(context) }
  }

  public var _debugTypeName: String {
    self.debugName ?? typeName(Self.self)
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value, Failure>
  ) async throws(Failure) -> Value {
    try await self._run(context, continuation)
  }
}
