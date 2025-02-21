import QueryCore

// MARK: - TestQuery

struct TestQuery: QueryProtocol, Hashable {
  static let value = 1

  typealias Value = Int

  func fetch(in context: QueryContext) async throws -> Value {
    Self.value
  }
}

// MARK: - TestStringQuery

struct TestStringQuery: QueryProtocol, Hashable {
  static let value = "Foo"

  func fetch(in context: QueryContext) async throws -> String {
    Self.value
  }
}
