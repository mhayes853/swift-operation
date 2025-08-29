import Foundation

// MARK: - OperationRequest

extension OperationRequest where State: DefaultableOperationState {
  public typealias Default = DefaultOperation<Self>

  /// Adds a default value to this operation.
  ///
  /// - Parameter value: The default value for this operation.
  /// - Returns: A ``DefaultOperation``.
  public func defaultValue(
    _ value: @autoclosure @escaping @Sendable () -> State.DefaultStateValue
  ) -> Default {
    DefaultOperation(operation: self, _defaultValue: value)
  }
}

// MARK: - DefaultOperation

public struct DefaultOperation<Operation: OperationRequest>: OperationRequest
where Operation.State: DefaultableOperationState {
  public typealias Value = Operation.Value
  public typealias State = DefaultOperationState<Operation.State>

  public let operation: Operation

  public var defaultValue: Operation.State.DefaultStateValue {
    self._defaultValue()
  }

  let _defaultValue: @Sendable () -> Operation.State.DefaultStateValue

  public var path: OperationPath {
    self.operation.path
  }

  public var _debugTypeName: String {
    self.operation._debugTypeName  // TODO: Change this
  }

  public func setup(context: inout OperationContext) {
    self.operation.setup(context: &context)
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value>
  ) async throws -> Value {
    try await self.operation.run(isolation: isolation, in: context, with: continuation)
  }
}

extension DefaultOperation: Sendable where Operation: Sendable {}

// MARK: - DefaultableOperationState

public protocol DefaultableOperationState: OperationState {
  associatedtype DefaultStateValue: Sendable

  func defaultValue(
    for value: StateValue,
    using defaultValue: DefaultStateValue
  ) -> DefaultStateValue

  func stateValue(for defaultStateValue: DefaultStateValue) -> StateValue
}

// MARK: - DefaultOperationState

public struct DefaultOperationState<Base: DefaultableOperationState>: OperationState {
  public typealias StatusValue = Base.StatusValue

  public var base: Base
  public let defaultValue: Base.DefaultStateValue

  public init(_ base: Base, defaultValue: Base.DefaultStateValue) {
    self.base = base
    self.defaultValue = defaultValue
  }

  public var currentValue: Base.DefaultStateValue {
    self.base.defaultValue(for: self.base.currentValue, using: self.defaultValue)
  }

  public var initialValue: Base.DefaultStateValue {
    self.base.defaultValue(for: self.base.initialValue, using: self.defaultValue)
  }

  public var valueUpdateCount: Int { self.base.valueUpdateCount }
  public var valueLastUpdatedAt: Date? { self.base.valueLastUpdatedAt }
  public var isLoading: Bool { self.base.isLoading }
  public var error: (any Error)? { self.base.error }
  public var errorUpdateCount: Int { self.base.errorUpdateCount }
  public var errorLastUpdatedAt: Date? { self.base.errorLastUpdatedAt }

  public mutating func scheduleFetchTask(_ task: inout OperationTask<Base.OperationValue>) {
    self.base.scheduleFetchTask(&task)
  }

  public mutating func reset(using context: OperationContext) -> ResetEffect {
    ResetEffect(tasksCancellable: self.base.reset(using: context).tasksCancellable)
  }

  public mutating func update(
    with result: Result<Base.DefaultStateValue, any Error>,
    using context: OperationContext
  ) {
    self.base.update(with: result.map { self.base.stateValue(for: $0) }, using: context)
  }

  public mutating func update(
    with result: Result<Base.OperationValue, any Error>,
    for task: OperationTask<Base.OperationValue>
  ) {
    self.base.update(with: result, for: task)
  }

  public mutating func finishFetchTask(_ task: OperationTask<Base.OperationValue>) {
    self.base.finishFetchTask(task)
  }
}
