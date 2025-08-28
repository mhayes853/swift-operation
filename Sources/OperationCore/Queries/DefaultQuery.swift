import Foundation

// MARK: - DefaultQuery

extension QueryRequest {

  /// Adds a default value to this query.
  ///
  /// - Parameter value: The default value for this query.
  /// - Returns: A ``DefaultQuery``.
  public func defaultValue(
    _ value: @autoclosure @escaping @Sendable () -> Value
  ) -> Default {
    _DefaultQuery(_defaultValue: value, query: self)
  }
}

/// A query that provides a default value to a ``QueryRequest``.
///
/// You create instances of this query through ``QueryRequest/defaultValue(_:)``.
public struct _DefaultQuery<Query: QueryRequest>: QueryRequest {
  public typealias State = DefaultQueryState<Query.Value>

  let _defaultValue: @Sendable () -> Query.Value

  /// The base query.
  public let query: Query

  /// The default value of this query.
  public var defaultValue: Query.Value {
    self._defaultValue()
  }

  public var path: OperationPath {
    self.query.path
  }

  public var _debugTypeName: String {
    self.query._debugTypeName
  }

  public func setup(context: inout OperationContext) {
    self.query.setup(context: &context)
  }

  public func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await self.query.fetch(isolation: isolation, in: context, with: continuation)
  }
}

// MARK: - DefaultQueryState

public struct DefaultQueryState<Value: Sendable>: _QueryStateProtocol {
  public typealias StateValue = Value
  public typealias OperationValue = Value
  public typealias StatusValue = Value

  public let defaultValue: Value
  private var base: QueryState<Value>

  public init(_ base: QueryState<Value>, defaultValue: Value) {
    self.base = base
    self.defaultValue = defaultValue
  }

  public var currentValue: StateValue {
    self.base.currentValue ?? self.defaultValue
  }

  public var initialValue: StateValue {
    self.base.initialValue ?? self.defaultValue
  }

  public var valueUpdateCount: Int { self.base.valueUpdateCount }
  public var valueLastUpdatedAt: Date? { self.base.valueLastUpdatedAt }
  public var isLoading: Bool { self.base.isLoading }
  public var error: (any Error)? { self.base.error }
  public var errorUpdateCount: Int { self.base.errorUpdateCount }
  public var errorLastUpdatedAt: Date? { self.base.errorLastUpdatedAt }
  public var activeTasks: IdentifiedArrayOf<OperationTask<Value>> { self.base.activeTasks }

  public mutating func scheduleFetchTask(
    _ task: inout OperationTask<OperationValue>
  ) {
    self.base.scheduleFetchTask(&task)
  }

  public mutating func reset(using context: OperationContext) -> ResetEffect {
    ResetEffect(tasksCancellable: self.base.reset(using: context).tasksCancellable)
  }

  public mutating func update(
    with result: Result<OperationValue, any Error>,
    for task: OperationTask<OperationValue>
  ) {
    self.base.update(with: result, for: task)
  }

  public mutating func update(
    with result: Result<StateValue, any Error>,
    using context: OperationContext
  ) {
    self.base.update(with: result.map { $0 as Value? }, using: context)
  }

  public mutating func finishFetchTask(_ task: OperationTask<OperationValue>) {
    self.base.finishFetchTask(task)
  }
}
