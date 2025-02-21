public protocol QueryProtocol<Value>: Hashable, Sendable {
  associatedtype Value: Sendable

  func fetch(in context: QueryContext) async throws -> Value
}
