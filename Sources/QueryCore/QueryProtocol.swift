public protocol QueryProtocol<Value>: Sendable {
  associatedtype Value: Sendable

  associatedtype _StateValue: Sendable = Value?

  var path: QueryPath { get }

  func fetch(in context: QueryContext) async throws -> Value
}

extension QueryProtocol {
  public typealias _StateValue = Value?
}

extension QueryProtocol where Self: Hashable {
  public var path: QueryPath { [self] }
}
