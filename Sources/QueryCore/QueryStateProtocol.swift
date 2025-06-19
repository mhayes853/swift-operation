import Foundation

/// A protocol for the state of a query.
///
/// Each ``QueryRequest`` has an associated type that denotes the structure of its state inside a
/// ``QueryStore``. By default, ``QueryState`` is the state that is used for a `QueryRequest`.
/// However, ``MutationRequest`` and ``InfiniteQueryRequest`` use ``MutationState`` and
/// ``InfiniteQueryState`` respectively as their ``QueryRequest/State`` types.
///
/// You typically do not interact with the `mutating` methods on this protocol directly, rather a
/// ``QueryStore`` instance will invoke them as needed. Most commonly, you will access the
/// properties on this protocol to render your UI based the state of a `QueryRequest`.
///
/// You can also create your own conformance to this protocol if you need to create a custom
/// state type for your query. Generally, you should only need to do this if you want to define a
/// new fetching paradigmn, which is rare. See <doc:CustomParadigms> to learn how to do this.
///
/// > Warning: You should not call any of the `mutating` methods directly on this type, rather a
/// > ``QueryStore`` will call them at the appropriate time for you.
public protocol QueryStateProtocol<StateValue, QueryValue>: Sendable {
  /// The type of value that is held in the state directly.
  ///
  /// This can differ from ``QueryValue`` as the latter represents the value for a successful fetch,
  /// whereas this associated type represents the value currently present in the state. For
  /// instance, this type in ``QueryState`` may be an optional while ``QueryValue`` may not be an
  /// optional because a nil value would mean that the query has never been fetched.
  associatedtype StateValue: Sendable
  
  /// The type of value for a successful fetch from a query.
  associatedtype QueryValue: Sendable
  
  /// The type of value that is accessed from the <doc:/documentation/QueryCore/QueryStateProtocol/status-34hpq> property.
  associatedtype StatusValue: Sendable

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
  /// This property is true when active ``QueryTask`` instances are scheduled on the query state
  /// regardless of whether or not ``QueryTask/isRunning`` is true.
  var isLoading: Bool { get }
  
  /// The most recent error thrown by the query driving this state.
  ///
  /// When a query finishes a successful fetch, this property is set to nil.
  var error: (any Error)? { get }
  
  /// The number of times ``error`` was updated. (Not counting setting it to nil on a successful
  /// query fetch).
  var errorUpdateCount: Int { get }
  
  /// The most recent date when ``error`` was updated. Not counting setting it to nil on a
  /// successful query fetch).
  var errorLastUpdatedAt: Date? { get }
  
  /// Schedules a ``QueryTask`` on this state.
  ///
  /// A ``QueryStateProtocol`` conformance is required to hold the instances of all active tasks
  /// created by a ``QueryStore``. The store calls this method when a new task is created.
  ///
  /// - Parameter task: The ``QueryTask`` to schedule on this state.
  mutating func scheduleFetchTask(_ task: inout QueryTask<QueryValue>)
  
  /// Resets this state using the provided ``QueryContext``.
  ///
  /// This method is called when ``QueryStore/reset(using:)`` is called.
  ///
  /// Make sure to cancel all active ``QueryTask`` instances held by this state, and then reset all
  /// properties back to their default values.
  ///
  /// - Parameter context: The context to reset this state in.
  mutating func reset(using context: QueryContext)
  
  /// Updates the state of this query based on the provided result.
  ///
  /// This method is called when setting ``QueryStore/currentValue`` directly through a query store,
  /// or when ``QueryControls/yield(with:using:)`` is called from within a ``QueryController``.
  ///
  /// If `result` is a successful `Result`, make sure to set ``error`` to nil.
  ///
  /// - Parameters:
  ///   - result: The new value to ingest into this state.
  ///   - context: The ``QueryContext`` of this update.
  mutating func update(
    with result: Result<StateValue, any Error>,
    using context: QueryContext
  )
  
  /// Updates the state of a query based on a fetch result.
  ///
  /// This method is called when a query fetch finishes, or when a result is yielded through
  /// ``QueryContinuation/yield(with:using:)``.
  ///
  /// If `result` is a successful `Result`, make sure to set ``error`` to nil.
  ///
  /// - Parameters:
  ///   - result: The query result to ingest into this state.
  ///   - task: The ``QueryTask`` that the update came from.
  mutating func update(
    with result: Result<QueryValue, any Error>,
    for task: QueryTask<QueryValue>
  )
  
  /// Indicates to this state that a ``QueryTask`` is about to finish running.
  ///
  /// This method is called by ``QueryStore`` when a query fetch finishes, and is the last step in
  /// the specified task's body.
  ///
  /// Make sure to remove the task instance from this state. If you store this state's tasks in a
  /// collection, you can use the ``QueryTask/id`` property to lookup the index of the task in
  /// your collection, and remove the task based on that index.
  ///
  /// - Parameter task: The ``QueryTask`` that is about to finish running.
  mutating func finishFetchTask(_ task: QueryTask<QueryValue>)
}
