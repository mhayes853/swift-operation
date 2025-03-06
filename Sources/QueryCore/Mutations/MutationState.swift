import Foundation

// MARK: - MutationState

public struct MutationState<Value: Sendable> {

}

// MARK: - QueryStateProtocol

extension MutationState: QueryStateProtocol {
  public typealias StateValue = Value?
  public typealias StatusValue = Value
  public typealias QueryValue = Value

  public var currentValue: StateValue {
    fatalError()
  }

  public var initialValue: StateValue {
    fatalError()
  }

  public var valueUpdateCount: Int {
    fatalError()
  }

  public var valueLastUpdatedAt: Date? {
    fatalError()
  }

  public var isLoading: Bool {
    fatalError()
  }

  public var error: (any Error)? {
    fatalError()
  }

  public var errorUpdateCount: Int {
    fatalError()
  }

  public var errorLastUpdatedAt: Date? {
    fatalError()
  }

  public mutating func startFetchTask(
    in context: QueryContext,
    for fn: @escaping @Sendable () async throws -> any Sendable
  ) -> Task<any Sendable, any Error> {
    fatalError()
  }

  public mutating func endFetchTask(
    in context: QueryContext,
    with result: Result<QueryValue, any Error>
  ) {
    fatalError()
  }
}
