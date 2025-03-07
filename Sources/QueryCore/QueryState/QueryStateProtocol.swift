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

  mutating func startFetchTask(_ task: QueryTask<QueryValue>) -> QueryTask<QueryValue>

  mutating func endFetchTask(
    _ task: QueryTask<QueryValue>,
    with result: Result<QueryValue, any Error>
  )
}
