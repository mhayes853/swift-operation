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
