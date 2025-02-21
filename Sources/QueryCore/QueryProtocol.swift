public protocol QueryProtocol<Value>: Sendable {
  associatedtype Value: Sendable
  associatedtype ID: Hashable = Self

  var id: ID { get }

  func fetch(in context: QueryContext) async throws -> Value
}

extension QueryProtocol where ID == Self {
  public var id: ID { self }
}
