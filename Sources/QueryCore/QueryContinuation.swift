// MARK: - QueryContinuation

public struct QueryContinuation<Value: Sendable>: Sendable {
  private let onQueryResult: @Sendable (Result<Value, any Error>, QueryContext?) -> Void

  public init(
    onQueryResult: @escaping @Sendable (Result<Value, any Error>, QueryContext?) -> Void
  ) {
    self.onQueryResult = onQueryResult
  }
}

// MARK: - Yielding

extension QueryContinuation {
  public func yield(_ value: Value, using context: QueryContext? = nil) {
    self.yield(with: .success(value), using: context)
  }

  public func yield(error: any Error, using context: QueryContext? = nil) {
    self.yield(with: .failure(error), using: context)
  }

  public func yield(with result: Result<Value, any Error>, using context: QueryContext? = nil) {
    self.onQueryResult(result, context)
  }
}
