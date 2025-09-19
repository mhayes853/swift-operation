import Foundation
import IdentifiedCollections

/// A protocol for the state of an operation.
///
/// Each ``StatefulOperationRequest`` has an associated type that denotes the structure of its
/// state inside a ``OperationStore``. Protocols that inherit from `StatefulOperationRequest` such
/// as ``QueryRequest`` and ``PaginatedRequest`` define their own state types as ``QueryState`` and
/// ``MutationState`` respectively.
///
/// If you decide to create your own operation type by following <doc:CustomOperationTypes>, you
/// may also need to create a concrete conformance to this protocol in order to describe how the state
/// management capabilities of your custom operation type.
///
/// You typically do not interact with the `mutating` methods on this protocol directly, rather an
/// ``OperationStore`` instance will invoke them as needed. Most commonly, you will access the
/// properties on this protocol to render your UI based the state of an operation.
///
/// > Warning: You should not call any of the `mutating` methods directly on this type, rather an
/// > ``OperationStore`` will call them at the appropriate time for you.
public protocol OperationState<StateValue, OperationValue, Failure> {
  /// A data type returned from ``reset(using:)`` that determines the action that the
  /// ``OperationStore`` should take when ``OperationStore/resetState(using:)`` is called.
  typealias ResetEffect = OperationStateResetEffect<Self>

  /// The type of value that represents the state of the value returned by the most recent
  /// operation run.
  ///
  /// This can differ from ``OperationValue`` as the latter represents the value for a successful
  /// run, whereas this associated type represents the value currently present in the state that
  /// should be rendered in the UI. For instance, this type in ``QueryState`` may be an optional
  /// while ``OperationValue`` may not be an optional because a nil value would mean that the
  /// query has never been ran.
  associatedtype StateValue: Sendable

  /// The type of value for a successful run from an operation.
  ///
  /// This is generally the value returned directly from calling
  /// ``OperationRequest/run(isolation:in:with:)``.
  associatedtype OperationValue: Sendable

  /// The type of value that is accessed from the
  /// <doc:/documentation/OperationCore/OperationState/status-87th9> property.
  associatedtype StatusValue: Sendable

  /// The type of error for an unsuccessful frun from an operation.
  ///
  /// This is generally the error thrown from directly calling
  /// ``OperationRequest/run(isolation:in:with:)``.
  associatedtype Failure: Error

  /// The current value of this state.
  var currentValue: StateValue { get }

  /// The initial value of this state.
  var initialValue: StateValue { get }

  /// The number of times that ``currentValue`` has been updated.
  var valueUpdateCount: Int { get }

  /// The most recent date when ``currentValue`` was updated.
  var valueLastUpdatedAt: Date? { get }

  /// Whether or not the operation driving this state has active tasks associated with it.
  ///
  /// This property is true when active ``OperationTask`` instances are scheduled on the query state
  /// regardless of whether or not ``OperationTask/isRunning`` is true.
  var isLoading: Bool { get }

  /// The most recent error thrown by the operation driving this state.
  ///
  /// When an operation finishes a successful run, this property is set to nil.
  var error: Failure? { get }

  /// The number of times ``error`` was updated. (Not counting setting it to nil on a successful
  /// operation run).
  var errorUpdateCount: Int { get }

  /// The most recent date when ``error`` was updated. (Not counting setting it to nil on a
  /// successful operation run).
  var errorLastUpdatedAt: Date? { get }

  /// Schedules an ``OperationTask`` on this state.
  ///
  /// An ``OperationState`` conformance is required to hold the instances of all active tasks
  /// created by a ``OperationStore``. The store calls this method when a new task is created.
  ///
  /// - Parameter task: The ``OperationTask`` to schedule on this state.
  mutating func scheduleFetchTask(_ task: inout OperationTask<OperationValue, Failure>)

  /// Resets this state using the provided ``OperationContext``.
  ///
  /// This method is called when ``OperationStore/resetState(using:)`` is called, and you return a
  /// <doc:/documentation/OperationCore/OperationState/ResetEffect> back to the store. This effect
  /// contains the ``OperationTask`` instances that the store should cancel. Do not cancel any
  /// tasks that are held by this state within this method.
  ///
  /// Make sure to reset all properties back to their default values, as if the state was just
  /// created with its initial value.
  ///
  /// - Parameter context: The context to reset this state in.
  mutating func reset(using context: OperationContext) -> ResetEffect

  /// Updates the state of this operation based on the provided result.
  ///
  /// This method is called when setting ``OperationStore/currentValue`` directly through an
  /// ``OperationStore``, or when ``OperationControls/yield(with:using:)`` is called from within a
  /// ``OperationController``.
  ///
  /// If `result` is a successful `Result`, make sure to set ``error`` to nil.
  ///
  /// - Parameters:
  ///   - result: The new value to ingest into this state.
  ///   - context: The ``OperationContext`` of this update.
  mutating func update(
    with result: Result<StateValue, Failure>,
    using context: OperationContext
  )

  /// Updates the state of an operation based on the result of a run.
  ///
  /// This method is called when an operation run finishes, or when a result is yielded through
  /// ``OperationContinuation/yield(with:using:)``.
  ///
  /// If `result` is a successful `Result`, make sure to set ``error`` to nil (do not set
  /// ``errorUpdateCount`` or ``errorLastUpdatedAt`` when doing this).
  ///
  /// - Parameters:
  ///   - result: The operation result to ingest into this state.
  ///   - task: The ``OperationTask`` that the update came from.
  mutating func update(
    with result: Result<OperationValue, Failure>,
    for task: OperationTask<OperationValue, Failure>
  )

  /// Indicates to this state that a ``OperationTask`` is about to finish running.
  ///
  /// This method is called by ``OperationStore`` when an operation run finishes, and is the last
  /// step in the specified task's body.
  ///
  /// Make sure to remove the task instance from this state. If you store this state's tasks in a
  /// collection, you can use the ``OperationTask/id`` property to lookup the index of the task in
  /// your collection, and remove the task based on that index.
  ///
  /// - Parameter task: The ``OperationTask`` that is about to finish running.
  mutating func finishFetchTask(_ task: OperationTask<OperationValue, Failure>)
}

// MARK: - ResetEffect

/// A data type returned from ``OperationState/reset(using:)`` that determines the action that the
/// ``OperationStore`` should take when ``OperationStore/resetState(using:)`` is called.
public struct OperationStateResetEffect<State: OperationState>: Sendable {
  /// Cancels all ``OperationTask`` instances returned from ``OperationState/reset(using:)``.
  public let tasksCancellable: OperationSubscription

  /// Creates a reset effect with a subscription to cancel ``OperationTask`` instances.
  ///
  /// - Parameter tasksCancellable: The subscription to cancel `OperationTask` instances.
  public init(tasksCancellable: OperationSubscription) {
    self.tasksCancellable = tasksCancellable
  }

  /// Creates a reset effect that cancels the specified ``OperationTask`` instances.
  ///
  /// - Parameter tasksToCancel: The tasks to cancel.
  public init(tasksToCancel: some Sequence<OperationTask<State.OperationValue, State.Failure>>) {
    let subscriptions = tasksToCancel.map { task in
      OperationSubscription { task.cancel() }
    }
    self.tasksCancellable = .combined(subscriptions)
  }
}
