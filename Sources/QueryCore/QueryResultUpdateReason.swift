// MARK: - QueryResultUpdateReason

public enum QueryResultUpdateReason: Hashable, Sendable {
  case yieldedResult
  case returnedFinalResult
}

// MARK: - QueryContext

extension QueryContext {
  public var queryResultUpdateReason: QueryResultUpdateReason {
    get { self[QueryResultUpdateReasonKey.self] }
    set { self[QueryResultUpdateReasonKey.self] = newValue }
  }

  private enum QueryResultUpdateReasonKey: Key {
    static let defaultValue = QueryResultUpdateReason.returnedFinalResult
  }
}
