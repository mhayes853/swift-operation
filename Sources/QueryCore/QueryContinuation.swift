// MARK: - QueryContinuation

public struct QueryContinuation<Value: Sendable>: Sendable {
  private let onQueryResult: @Sendable (Result<Value, any Error>) -> Void

  public init(
    onQueryResult: @escaping @Sendable (Result<Value, any Error>) -> Void
  ) {
    self.onQueryResult = onQueryResult
  }
}

// MARK: - Yielding

extension QueryContinuation {
  public func yield(_ value: Value) {
    self.yield(with: .success(value))
  }

  public func yield(error: any Error) {
    self.yield(with: .failure(error))
  }

  public func yield(with result: Result<Value, any Error>) {
    self.onQueryResult(result)
  }
}
