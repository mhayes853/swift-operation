import Foundation

// MARK: - OperationRequest

extension StatefulOperationRequest where State: DefaultableOperationState {
  /// This operation with a default value attached.
  public typealias Default = DefaultStateOperation<Self>

  /// Adds a type-safe default value to this operation.
  ///
  /// When declaring a default value for an operation, the operation gains type-safety on the
  /// default value. For instance, applying a default value to a ``QueryRequest`` that returns an
  /// optional will ensure that the value of the query's state will be non-optional.
  ///
  /// ```swift
  /// struct SomeValue {
  ///   static let defaultValue = SomeValue()
  ///   // ...
  /// }
  ///
  /// extension SomeValue {
  ///   static func query(
  ///     for id: Int
  ///   ) -> (some QueryRequest<Self?, any Error>).Default {
  ///     Query(id: id).defaultValue(.defaultValue)
  ///   }
  ///
  ///   struct Query: QueryRequest, Hashable {
  ///     let id: Int
  ///
  ///     func fetch(
  ///       isolation: isolated (any Actor)?,
  ///       in context: OperationContext,
  ///       with continuation: OperationContinuation<SomeValue?, any Error>
  ///     ) async throws -> SomeValue? {
  ///       // ...
  ///     }
  ///   }
  /// }
  ///
  /// let store = OperationStore.detached(query: SomeValue.query(for: 10))
  /// print(store.currentValue) // ✅ currentValue is non-optional
  /// ```
  ///
  /// > Note: If you declare a query like in the example above, you must ensure that the call to
  /// > `defaultValue` is last in the chain. Otherwise, your code will not compile.
  ///
  /// - Parameter value: The default value for this operation.
  /// - Returns: A ``DefaultStateOperation``.
  public func defaultValue(
    _ value: @autoclosure @escaping @Sendable () -> State.DefaultStateValue
  ) -> Default {
    DefaultStateOperation(operation: self, _defaultValue: value)
  }
}

// MARK: - DefaultOperation

/// A ``StatefulOperationRequest`` that applies a default value to the state of an operation.
///
/// You don't create instances of this operation type directly. Rather, you apply the
/// ``StatefulOperationRequest/defaultValue(_:)`` modifier to an operation.
///
/// The base operation's state type must conform to ``DefaultableOperationState``.
public struct DefaultStateOperation<Operation: StatefulOperationRequest>: StatefulOperationRequest
where Operation.State: DefaultableOperationState {
  public typealias Value = Operation.Value
  public typealias State = DefaultOperationState<Operation.State>

  /// The base operation.
  public let operation: Operation

  /// The default value for this operation.
  public var defaultValue: Operation.State.DefaultStateValue {
    self._defaultValue()
  }

  let _defaultValue: @Sendable () -> Operation.State.DefaultStateValue

  public var path: OperationPath {
    self.operation.path
  }

  public var _debugTypeName: String {
    "\(self.operation._debugTypeName).Default"
  }

  public func setup(context: inout OperationContext) {
    self.operation.setup(context: &context)
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value, Failure>
  ) async throws(Operation.Failure) -> Value {
    try await self.operation.run(isolation: isolation, in: context, with: continuation)
  }
}

extension DefaultStateOperation: Sendable where Operation: Sendable {}

// MARK: - DefaultableOperationState

/// An ``OperationState`` that provides a type-safe default value.
public protocol DefaultableOperationState: OperationState {
  /// The type of the default value.
  ///
  /// If ``OperationState/StateValue`` is an optional, this is typically a non-optional version of
  /// that type.
  associatedtype DefaultStateValue: Sendable

  /// Returns the current value of this state based on the default value.
  ///
  /// - Parameter defaultValue: The default value of the operation state.
  /// - Returns: The current state's value based on the default value.
  func currentValue(using defaultValue: DefaultStateValue) -> DefaultStateValue

  /// Returns the initial value of this state based on the default value.
  ///
  /// - Parameter defaultValue: The default value of the operation state.
  /// - Returns: The initial state's value based on the default value.
  func initialValue(using defaultValue: DefaultStateValue) -> DefaultStateValue

  /// Converts a value of type ``DefaultStateValue`` to a value of the base
  /// ``OperationState/StateValue`` type on this state.
  ///
  /// The value passed to this method is generally not the default value of the state, but rather a
  /// value with same type as the default value.
  ///
  /// - Parameter defaultStateValue: A value with the same type as the default value.
  /// - Returns: `defaultStateValue` converted to a value with of the base `StateValue` type on
  ///   this state.
  func stateValue(for defaultStateValue: DefaultStateValue) -> StateValue
}

extension DefaultableOperationState {
  public func initialValue(using defaultValue: DefaultStateValue) -> DefaultStateValue {
    defaultValue
  }
}

extension DefaultableOperationState where DefaultStateValue == StateValue {
  public func stateValue(for defaultStateValue: DefaultStateValue) -> StateValue {
    defaultStateValue
  }
}

extension DefaultableOperationState
where StateValue: _OptionalProtocol, DefaultStateValue == StateValue.Wrapped {
  public func currentValue(using defaultValue: DefaultStateValue) -> DefaultStateValue {
    self.currentValue._orElse(unwrapped: defaultValue)
  }

  public func stateValue(for defaultStateValue: DefaultStateValue) -> StateValue {
    StateValue._from(wrapped: defaultStateValue)
  }
}

// MARK: - DefaultOperationState

/// An ``OperationState`` with a default value applied onto a base state.
public struct DefaultOperationState<Base: DefaultableOperationState>: OperationState {
  public typealias StatusValue = Base.StatusValue

  /// The base state.
  public private(set) var base: Base

  /// The default value applied to the base state.
  public let defaultValue: Base.DefaultStateValue

  /// Creates a default operation state.
  ///
  /// - Parameters:
  ///   - base: The base state to apply the default value to.
  ///   - defaultValue: The default value.
  public init(_ base: Base, defaultValue: Base.DefaultStateValue) {
    self.base = base
    self.defaultValue = defaultValue
  }

  public var currentValue: Base.DefaultStateValue {
    self.base.currentValue(using: self.defaultValue)
  }

  public var initialValue: Base.DefaultStateValue {
    self.base.initialValue(using: self.defaultValue)
  }

  public var valueUpdateCount: Int { self.base.valueUpdateCount }
  public var valueLastUpdatedAt: Date? { self.base.valueLastUpdatedAt }
  public var isLoading: Bool { self.base.isLoading }
  public var error: Base.Failure? { self.base.error }
  public var errorUpdateCount: Int { self.base.errorUpdateCount }
  public var errorLastUpdatedAt: Date? { self.base.errorLastUpdatedAt }

  public mutating func scheduleFetchTask(
    _ task: inout OperationTask<Base.OperationValue, Base.Failure>
  ) {
    self.base.scheduleFetchTask(&task)
  }

  public mutating func reset(using context: OperationContext) -> ResetEffect {
    ResetEffect(tasksCancellable: self.base.reset(using: context).tasksCancellable)
  }

  public mutating func update(
    with result: Result<Base.DefaultStateValue, Base.Failure>,
    using context: OperationContext
  ) {
    self.base.update(with: result.map { self.base.stateValue(for: $0) }, using: context)
  }

  public mutating func update(
    with result: Result<Base.OperationValue, Base.Failure>,
    for task: OperationTask<Base.OperationValue, Base.Failure>
  ) {
    self.base.update(with: result, for: task)
  }

  public mutating func finishFetchTask(_ task: OperationTask<Base.OperationValue, Base.Failure>) {
    self.base.finishFetchTask(task)
  }
}

extension DefaultOperationState: Hashable where Base: Hashable, Base.DefaultStateValue: Hashable {}
extension DefaultOperationState: Equatable
where Base: Equatable, Base.DefaultStateValue: Equatable {}
extension DefaultOperationState: Sendable where Base: Sendable, Base.DefaultStateValue: Sendable {}
