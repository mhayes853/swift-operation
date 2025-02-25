// MARK: - QueryEnableAutomaticFetchingCondition

public struct QueryEnableAutomaticFetchingCondition: Sendable {
  private enum Storage {
    case subscribedTo
    case fetchManuallyCalled
  }

  private let storage: Storage

  private init(_ storage: Storage) {
    self.storage = storage
  }
}

extension QueryEnableAutomaticFetchingCondition {
  public static let subscribedTo = Self(.subscribedTo)
  public static let fetchManuallyCalled = Self(.fetchManuallyCalled)
}

// MARK: - QueryProtocol

extension QueryProtocol {
  public func enableAutomaticFetching(
    when condition: QueryEnableAutomaticFetchingCondition
  ) -> some QueryProtocol<Value> {
    EnableAutomaticFetchingQuery(base: self, condition: condition)
  }
}

private struct EnableAutomaticFetchingQuery<Base: QueryProtocol>: QueryProtocol {
  let base: Base
  let condition: QueryEnableAutomaticFetchingCondition

  public var path: QueryPath {
    self.base.path
  }

  public func fetch(in context: QueryContext) async throws -> Base.Value {
    try await self.base.fetch(in: context)
  }
}
