import Foundation

public protocol QueryStateProtocol<StateValue, QueryValue>: Sendable {
  associatedtype StateValue: Sendable
  associatedtype QueryValue: Sendable
  associatedtype StatusValue: Sendable

  var currentValue: StateValue { get }
  var initialValue: StateValue { get }
  var valueUpdateCount: Int { get }
  var valueLastUpdatedAt: Date? { get }
  var isLoading: Bool { get }
  var error: (any Error)? { get }
  var errorUpdateCount: Int { get }
  var errorLastUpdatedAt: Date? { get }

  mutating func scheduleFetchTask(_ task: QueryTask<QueryValue>) -> QueryTask<QueryValue>

  mutating func update(
    with result: Result<StateValue, any Error>,
    using context: QueryContext
  )

  mutating func update(
    with result: Result<QueryValue, any Error>,
    for task: QueryTask<QueryValue>
  )

  mutating func finishFetchTask(_ task: QueryTask<QueryValue>)
}
