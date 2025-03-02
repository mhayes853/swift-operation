public protocol QueryProtocol<Value>: Sendable {
  associatedtype Value: Sendable

  associatedtype StateValue: Sendable = Value?
  associatedtype State: QueryStateProtocol = QueryState<StateValue, Value>

  var path: QueryPath { get }

  func _setup(context: inout QueryContext)

  func fetch(in context: QueryContext) async throws -> Value
}

extension QueryProtocol {
  public func _setup(context: inout QueryContext) {
  }
}

extension QueryProtocol where Self: Hashable {
  public var path: QueryPath { [self] }
}
