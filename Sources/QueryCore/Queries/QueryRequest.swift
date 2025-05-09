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

// MARK: - Setup

extension QueryRequest {
  public func setup(context: inout QueryContext) {
  }
}

// MARK: - Path Defaults

extension QueryRequest where Self: Hashable {
  public var path: QueryPath { [self] }
}

extension QueryRequest where Self: Identifiable, ID: Sendable {
  public var path: QueryPath { [self.id] }
}
