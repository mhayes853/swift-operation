public protocol QueryProtocol<Value>: Sendable {
  associatedtype Value: Sendable

  var path: QueryPath { get }

  func fetch(in context: QueryContext) async throws -> Value
}

extension QueryProtocol where Self: Hashable {
  public var path: QueryPath { [self] }
}
