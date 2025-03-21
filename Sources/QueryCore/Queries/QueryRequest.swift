// MARK: - QueryRequest

public protocol QueryRequest<Value>: Sendable {
  associatedtype Value: Sendable
  associatedtype State: QueryStateProtocol = QueryState<Value?, Value>

  var path: QueryPath { get }

  func setup(context: inout QueryContext)
  func fetch(
    in context: QueryContext,
    with continuation: QueryContinuation<Value>
  ) async throws -> Value
}

extension QueryRequest {
  public func setup(context: inout QueryContext) {
  }
}

extension QueryRequest where Self: Hashable {
  public var path: QueryPath { [self] }
}

// MARK: - QueryContinuation

public struct QueryContinuation<Value: Sendable>: Sendable {
  private let onQueryResult: @Sendable (Result<Value, any Error>) -> Void

  public init(
    onQueryResult: @escaping @Sendable (Result<Value, any Error>) -> Void
  ) {
    self.onQueryResult = onQueryResult
  }
}

extension QueryContinuation {
  public func yield(_ value: Value) {
    self.yield(with: .success(value))
  }

  public func yield(error: any Error) {
    self.yield(with: .failure(error))
  }

  public func yield(with result: Result<Value, any Error>) {
    self.onQueryResult(result)
  }
}
