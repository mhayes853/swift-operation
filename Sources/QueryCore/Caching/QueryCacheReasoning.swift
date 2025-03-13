// MARK: - QueryCacheSaveReason

public enum QueryCacheSaveReason: Sendable, Hashable {
  case userInitiated
  case newlyFetchedData
}

extension QueryContext {
  public var queryCacheSaveReason: QueryCacheSaveReason {
    get { self[QueryCacheSaveReasonKey.self] }
    set { self[QueryCacheSaveReasonKey.self] = newValue }
  }

  private enum QueryCacheSaveReasonKey: Key {
    static let defaultValue = QueryCacheSaveReason.userInitiated
  }
}

// MARK: - QueryCacheRemoveReason

public enum QueryCacheRemoveReason: Sendable, Hashable {
  case userInitiated
  case expiredData
}

extension QueryContext {
  public var queryCacheRemoveReason: QueryCacheRemoveReason {
    get { self[QueryCacheRemoveReasonKey.self] }
    set { self[QueryCacheRemoveReasonKey.self] = newValue }
  }

  private enum QueryCacheRemoveReasonKey: Key {
    static let defaultValue = QueryCacheRemoveReason.userInitiated
  }
}
