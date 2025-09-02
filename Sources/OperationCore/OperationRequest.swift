// MARK: - OperationRequest

public protocol OperationRequest<Value, Failure> {
  /// The data type that your query fetches.
  associatedtype Value

  associatedtype Failure: Error

  var _debugTypeName: String { get }

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
    with continuation: OperationContinuation<Value, Failure>
  ) async throws(Failure) -> Value
}

extension OperationRequest {
  public func setup(context: inout OperationContext) {
  }

  public var _debugTypeName: String { typeName(Self.self) }
}

// MARK: - StatefulOperationRequest

public protocol StatefulOperationRequest<State>: OperationRequest
where Value: Sendable, State.OperationValue == Value, State.Failure == Failure {
  /// The state type of your query.
  associatedtype State: OperationState

  /// A ``OperationPath`` that uniquely identifies your operation.
  ///
  /// If your operation conforms to Hashable or Identifiable, then this requirement is implemented by
  /// default. However, if you want to take advantage of pattern matching, then you'll want to
  /// implement this requirement manually.
  ///
  /// See <doc:PatternMatchingAndStateManagement> for more.
  var path: OperationPath { get }
}

// MARK: - Path Defaults

extension StatefulOperationRequest where Self: Hashable & Sendable {
  public var path: OperationPath {
    OperationPath(self)
  }
}

extension StatefulOperationRequest where Self: Identifiable, ID: Sendable {
  public var path: OperationPath {
    OperationPath(self.id)
  }
}
