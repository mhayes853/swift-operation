import Foundation
import IdentifiedCollections

/// A protocol for the state of a query.
///
/// Each ``QueryRequest`` has an associated type that denotes the structure of its state inside a
/// ``OperationStore``. By default, ``QueryState`` is the state that is used for a `QueryRequest`.
/// However, ``MutationRequest`` and ``InfiniteQueryRequest`` use ``MutationState`` and
/// ``InfiniteQueryState`` respectively as their ``QueryRequest/State`` types.
///
/// You typically do not interact with the `mutating` methods on this protocol directly, rather a
/// ``OperationStore`` instance will invoke them as needed. Most commonly, you will access the
/// properties on this protocol to render your UI based the state of a `QueryRequest`.
///
/// You can also create your own conformance to this protocol if you need to create a custom
/// state type for your query. Generally, you should only need to do this if you want to define a
/// new fetching paradigmn, which is rare. See <doc:CustomParadigms> to learn how to do this.
///
/// > Warning: You should not call any of the `mutating` methods directly on this type, rather a
/// > ``OperationStore`` will call them at the appropriate time for you.
public protocol OperationState<StateValue, OperationValue, Failure>: Sendable {
  /// A data type returned from ``reset(using:)`` that determines the action that the
  /// ``OperationStore`` should take when ``OperationStore/resetState(using:)`` is called.
  typealias ResetEffect = _OperationStateResetEffect<Self>

  /// The type of value that is held in the state directly.
  ///
  /// This can differ from ``QueryValue`` as the latter represents the value for a successful fetch,
  /// whereas this associated type represents the value currently present in the state. For
  /// instance, this type in ``QueryState`` may be an optional while ``QueryValue`` may not be an
  /// optional because a nil value would mean that the query has never been fetched.
  associatedtype StateValue: Sendable

  /// The type of value for a successful fetch from a query.
  associatedtype OperationValue: Sendable

  /// The type of value that is accessed from the <doc:/documentation/QueryCore/OperationState/status-34hpq> property.
  associatedtype StatusValue: Sendable

  associatedtype Failure: Error

  /// The current value of this state.
  var currentValue: StateValue { get }

  /// The initial value of this state.
  var initialValue: StateValue { get }

  /// The number of times that ``currentValue`` has been updated.
  var valueUpdateCount: Int { get }

  /// The most recent date when ``currentValue`` was updated.
  var valueLastUpdatedAt: Date? { get }

  /// Whether or not the query driving this state is loading.
  ///
  /// This property is true when active ``OperationTask`` instances are scheduled on the query state
  /// regardless of whether or not ``OperationTask/isRunning`` is true.
  var isLoading: Bool { get }

  /// The most recent error thrown by the query driving this state.
  ///
  /// When a query finishes a successful fetch, this property is set to nil.
  var error: Failure? { get }

  /// The number of times ``error`` was updated. (Not counting setting it to nil on a successful
  /// query fetch).
  var errorUpdateCount: Int { get }

  /// The most recent date when ``error`` was updated. Not counting setting it to nil on a
  /// successful query fetch).
  var errorLastUpdatedAt: Date? { get }

  /// Schedules a ``OperationTask`` on this state.
  ///
  /// A ``OperationState`` conformance is required to hold the instances of all active tasks
  /// created by a ``OperationStore``. The store calls this method when a new task is created.
  ///
  /// - Parameter task: The ``OperationTask`` to schedule on this state.
  mutating func scheduleFetchTask(_ task: inout OperationTask<OperationValue, Failure>)

  /// Resets this state using the provided ``OperationContext``.
  ///
  /// This method is called when ``OperationStore/resetState(using:)`` is called, and you return a
  /// ``ResetEffect`` back to the store. This effect contains the ``OperationTask`` instances that the
  /// store should cancel. Do not cancel any tasks that are held by this state within this method.
  ///
  /// Make sure to reset all properties back to their default values, as if the state was just
  /// created with its initial value.
  ///
  /// - Parameter context: The context to reset this state in.
  mutating func reset(using context: OperationContext) -> ResetEffect

  /// Updates the state of this query based on the provided result.
  ///
  /// This method is called when setting ``OperationStore/currentValue`` directly through a query store,
  /// or when ``OperationControls/yield(with:using:)`` is called from within a ``OperationController``.
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

  /// Updates the state of a query based on a fetch result.
  ///
  /// This method is called when a query fetch finishes, or when a result is yielded through
  /// ``OperationContinuation/yield(with:using:)``.
  ///
  /// If `result` is a successful `Result`, make sure to set ``error`` to nil.
  ///
  /// - Parameters:
  ///   - result: The query result to ingest into this state.
  ///   - task: The ``OperationTask`` that the update came from.
  mutating func update(
    with result: Result<OperationValue, Failure>,
    for task: OperationTask<OperationValue, Failure>
  )

  /// Indicates to this state that a ``OperationTask`` is about to finish running.
  ///
  /// This method is called by ``OperationStore`` when a query fetch finishes, and is the last step in
  /// the specified task's body.
  ///
  /// Make sure to remove the task instance from this state. If you store this state's tasks in a
  /// collection, you can use the ``OperationTask/id`` property to lookup the index of the task in
  /// your collection, and remove the task based on that index.
  ///
  /// - Parameter task: The ``OperationTask`` that is about to finish running.
  mutating func finishFetchTask(_ task: OperationTask<OperationValue, Failure>)
}

// MARK: - _QueryStateResetEffect

/// A data type returned from ``OperationState/reset(using:)`` that determines the action that the
/// ``OperationStore`` should take when ``OperationStore/resetState(using:)`` is called.
@_documentation(visibility: public)
public struct _OperationStateResetEffect<State: OperationState>: Sendable {
  /// Cancels all ``OperationTask`` instances returned from ``OperationState/reset(using:)``.
  public let tasksCancellable: OperationSubscription

  /// Creates a reset effect with a subscription to cancel ``OperationTask`` instances.
  ///
  /// - Parameter tasksCancellable: The subscription to cancel `OperationTask` instances.
  public init(tasksCancellable: OperationSubscription) {
    self.tasksCancellable = tasksCancellable
  }
}

extension _OperationStateResetEffect {
  /// Creates a reset effect that cancels the specified ``OperationTask`` instances.
  ///
  /// - Parameter tasksToCancel: The tasks to cancel.
  public init(tasksToCancel: some Sequence<OperationTask<State.OperationValue, State.Failure>>) {
    self.tasksCancellable = .combined(
      tasksToCancel.map { task in OperationSubscription { task.cancel() } }
    )
  }
}
