// MARK: - QueryCacheSaveReason

public struct QueryCacheSaveReason: Sendable, Hashable {
  private let rawValue: String
}

extension QueryCacheSaveReason {
  public static let userInitiated = Self(rawValue: "userInitiated")
  public static let newlyFetchedData = Self(rawValue: "newlyFetchedData")
}

extension QueryCacheSaveReason: CustomStringConvertible {
  public var description: String {
    self.rawValue
  }
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

public struct QueryCacheRemoveReason: Sendable, Hashable {
  private let rawValue: String
}

extension QueryCacheRemoveReason {
  public static let userInitiated = Self(rawValue: "userInitiated")
  public static let expiredData = Self(rawValue: "expiredData")
}

extension QueryCacheRemoveReason: CustomStringConvertible {
  public var description: String {
    self.rawValue
  }
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
