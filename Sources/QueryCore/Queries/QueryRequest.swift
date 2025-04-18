// MARK: - QueryRequest

public protocol QueryRequest<Value, State>: Sendable where State.QueryValue == Value {
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
