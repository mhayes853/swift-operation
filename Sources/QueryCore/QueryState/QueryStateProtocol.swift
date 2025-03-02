import Foundation

public protocol QueryStateProtocol<StateValue, QueryValue>: Sendable {
  associatedtype StateValue: Sendable
  associatedtype QueryValue: Sendable

  var currentValue: StateValue { get }
  var initialValue: StateValue { get }
  var valueUpdateCount: Int { get }
  var valueLastUpdatedAt: Date? { get }
  var isLoading: Bool { get }
  var error: (any Error)? { get }
  var errorUpdateCount: Int { get }
  var errorLastUpdatedAt: Date? { get }
  var fetchTask: Task<any Sendable, any Error>? { get }

  func casted<NewValue: Sendable, NewQueryValue: Sendable>(
    to newValue: NewValue.Type,
    newQueryValue: NewQueryValue.Type
  ) -> (any QueryStateProtocol)?

  mutating func startFetchTask(
    for fn: @Sendable @escaping () async throws -> any Sendable
  ) -> Task<any Sendable, any Error>

  mutating func endFetchTask(with value: StateValue)

  mutating func finishFetchTask(with error: any Error)

  init(initialValue: StateValue)
}
