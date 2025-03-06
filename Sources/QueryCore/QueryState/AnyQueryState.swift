import Foundation

// MARK: - AnyQueryState

public struct AnyQueryState {
  public private(set) var base: any QueryStateProtocol

  public init(_ base: any QueryStateProtocol) {
    self.base = base
  }
}

// MARK: - QueryStateProtocol

extension AnyQueryState: QueryStateProtocol {
  public typealias StateValue = (any Sendable)?
  public typealias QueryValue = any Sendable
  public typealias StatusValue = any Sendable

  public var currentValue: StateValue { self.base.currentValue }
  public var initialValue: StateValue { self.base.initialValue }
  public var valueUpdateCount: Int { self.base.valueUpdateCount }
  public var valueLastUpdatedAt: Date? { self.base.valueLastUpdatedAt }
  public var isLoading: Bool { self.base.isLoading }
  public var error: (any Error)? { self.base.error }
  public var errorUpdateCount: Int { self.base.errorUpdateCount }
  public var errorLastUpdatedAt: Date? { self.base.errorLastUpdatedAt }

  public mutating func startFetchTask(
    in context: QueryContext,
    for fn: @escaping @Sendable () async throws -> any Sendable
  ) -> Task<any Sendable, any Error> {
    self.base.startFetchTask(in: context, for: fn)
  }

  public mutating func endFetchTask(
    in context: QueryContext,
    with result: Result<QueryValue, any Error>
  ) {
    func open<State: QueryStateProtocol>(state: inout State) {
      state.endFetchTask(in: context, with: result.map { $0 as! State.QueryValue })
    }
    open(state: &self.base)
  }
}
