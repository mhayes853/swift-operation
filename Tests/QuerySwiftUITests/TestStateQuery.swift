import QueryCore

struct TestStateQuery: QueryRequest, Hashable {
  enum Action {
    case load, suspend, fail
  }

  static let action = Lock(Action.load)

  static let successValue = "Success"

  typealias Value = String

  struct SomeError: Hashable, Error {}

  func setup(context: inout QueryContext) {
    context.enableAutomaticFetchingCondition = .always(false)
  }

  func fetch(
    in context: QueryCore.QueryContext,
    with continuation: QueryCore.QueryContinuation<Value>
  ) async throws -> Value {
    let task = Self.action.withLock { action in
      switch action {
      case .load:
        return Task { () async throws -> String in
          return Self.successValue
        }
      case .suspend:
        return Task {
          try await Task.never()
          throw SomeError()
        }
      case .fail:
        return Task { throw SomeError() }
      }
    }
    return try await task.value
  }
}
