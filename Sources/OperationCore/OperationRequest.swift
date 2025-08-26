// MARK: - OperationRequest

public protocol OperationRequest<Value, State>: OperationPathable
where State.OperationValue == Value {
  /// The data type that your query fetches.
  associatedtype Value: Sendable

  /// The state type of your query.
  associatedtype State: OperationState

  var _debugTypeName: String { get }

  /// A ``OperationPath`` that uniquely identifies your operation.
  ///
  /// If your operation conforms to Hashable or Identifiable, then this requirement is implemented by
  /// default. However, if you want to take advantage of pattern matching, then you'll want to
  /// implement this requirement manually.
  ///
  /// See <doc:PatternMatchingAndStateManagement> for more.
  var path: OperationPath { get }

  /// Sets up the initial ``OperationContext`` that gets passed to ``fetch(in:with:)``.
  ///
  /// This method is called a single time when a ``OperationStore`` is initialized with your operation.
  ///
  /// - Parameter context: The context to setup.
  func setup(context: inout OperationContext)

  /// Fetches the data for your operation.
  ///
  /// - Parameters:
  ///   - context: An ``OperationContext`` that is passed to your operation.
  ///   - continuation: An ``OperationContinuation`` that allows you to yield values while you're
  ///     fetching data. See <doc:MultistageQueries> for more.
  /// - Returns: The fetched value from your operation.
  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value>
  ) async throws -> Value
}

// MARK: - Setup

extension OperationRequest {
  public func setup(context: inout OperationContext) {
  }
}

// MARK: - Path Defaults

extension OperationRequest where Self: Hashable & Sendable {
  public var path: OperationPath {
    OperationPath(self)
  }
}

extension OperationRequest where Self: Identifiable, ID: Sendable {
  public var path: OperationPath {
    OperationPath(self.id)
  }
}

// MARK: - Debug Type Name Default

extension OperationRequest {
  public var _debugTypeName: String { typeName(Self.self) }
}
