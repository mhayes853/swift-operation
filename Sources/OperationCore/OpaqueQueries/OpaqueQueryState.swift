import Foundation

// MARK: - OpaqueOperationState

/// An untyped state type that type erases any ``OperationState`` conformance.
///
/// Generally, you only access this type from an ``OpaqueOperationStore``, which is typically accessed
/// via pattern matching on a ``OperationClient``. See <doc:PatternMatchingAndStateManagement> for more.
public struct OpaqueOperationState {
  /// The underlying base state.
  public private(set) var base: any OperationState

  /// Creates an opaque state.
  ///
  /// - Parameter base: The base state to erase.
  public init(_ base: any OperationState) {
    self.base = base
  }
}

// MARK: - OperationState

extension OpaqueOperationState: OperationState {
  public typealias StateValue = any Sendable
  public typealias OperationValue = any Sendable
  public typealias StatusValue = any Sendable

  public var currentValue: StateValue { self.base.currentValue }
  public var initialValue: StateValue { self.base.initialValue }
  public var valueUpdateCount: Int { self.base.valueUpdateCount }
  public var valueLastUpdatedAt: Date? { self.base.valueLastUpdatedAt }
  public var isLoading: Bool { self.base.isLoading }
  public var error: (any Error)? { self.base.error }
  public var errorUpdateCount: Int { self.base.errorUpdateCount }
  public var errorLastUpdatedAt: Date? { self.base.errorLastUpdatedAt }

  public mutating func scheduleFetchTask(
    _ task: inout OperationTask<any Sendable>
  ) {
    func open<State: OperationState>(state: inout State) {
      var inner = task.map { $0 as! State.OperationValue }
      state.scheduleFetchTask(&inner)
      task = inner.map { $0 as any Sendable }
    }
    open(state: &self.base)
  }

  public mutating func reset(using context: OperationContext) -> ResetEffect {
    func open<State: OperationState>(state: inout State) -> ResetEffect {
      ResetEffect(tasksCancellable: state.reset(using: context).tasksCancellable)
    }
    return open(state: &self.base)
  }

  public mutating func update(
    with result: Result<any Sendable, any Error>,
    for task: OperationTask<any Sendable>
  ) {
    func open<State: OperationState>(state: inout State) {
      state.update(
        with: result.map { $0 as! State.OperationValue },
        for: task.map { $0 as! State.OperationValue }
      )
    }
    open(state: &self.base)
  }

  public mutating func update(
    with result: Result<any Sendable, any Error>,
    using context: OperationContext
  ) {
    func open<State: OperationState>(state: inout State) {
      state.update(with: result.map { $0 as! State.StateValue }, using: context)
    }
    open(state: &self.base)
  }

  public mutating func finishFetchTask(_ task: OperationTask<any Sendable>) {
    func open<State: OperationState>(state: inout State) {
      state.finishFetchTask(task.map { $0 as! State.OperationValue })
    }
    open(state: &self.base)
  }
}
