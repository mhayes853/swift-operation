// MARK: - QueryProtocol

public protocol QueryProtocol<Value>: Sendable {
  associatedtype Value: Sendable
  associatedtype State: QueryStateProtocol = QueryState<Value?, Value>

  var path: QueryPath { get }

  func setup(context: inout QueryContext)
  func fetch(in context: QueryContext) async throws -> Value
}

extension QueryProtocol {
  public func setup(context: inout QueryContext) {
  }
}

extension QueryProtocol where Self: Hashable {
  public var path: QueryPath { [self] }
}

// MARK: - QueryContinuation

public struct QueryContinuation<Query: QueryProtocol> {
  private let onQueryResult: @Sendable (Result<Query.State.QueryValue, any Error>) -> Void

  public init(
    onQueryResult: @escaping @Sendable (Result<Query.State.QueryValue, any Error>) -> Void
  ) {
    self.onQueryResult = onQueryResult
  }
}

extension QueryContinuation {
  public func yield(_ value: Query.State.QueryValue) {
    self.yield(with: .success(value))
  }

  public func yield(error: any Error) {
    self.yield(with: .failure(error))
  }

  public func yield(with result: Result<Query.State.QueryValue, any Error>) {
    onQueryResult(result)
  }
}
