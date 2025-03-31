#if canImport(Combine)
  import Combine
#endif

// MARK: - QueryStoreSubscription

public final class QuerySubscription: Sendable {
  private let onCancel: Lock<(@Sendable () -> Void)?>?

  public init(onCancel: @Sendable @escaping () -> Void) {
    self.onCancel = Lock(onCancel)
  }

  private init() {
    self.onCancel = nil
  }

  deinit { self.cancel() }
}

// MARK: - Empty

extension QuerySubscription {
  public static let empty = QuerySubscription()
}

// MARK: - Cancel

extension QuerySubscription {
  public func cancel() {
    self.onCancel?
      .withLock { cancel in
        defer { cancel = nil }
        cancel?()
      }
  }
}

// MARK: - Storing

extension QuerySubscription {
  public func store(in set: inout Set<QuerySubscription>) {
    set.insert(self)
  }

  public func store(in collection: inout some RangeReplaceableCollection<QuerySubscription>) {
    collection.append(self)
  }
}

// MARK: - Equatable

extension QuerySubscription: Equatable {
  public static func == (lhs: QuerySubscription, rhs: QuerySubscription) -> Bool {
    lhs === rhs
  }
}

// MARK: - Hashable

extension QuerySubscription: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

// MARK: - Combine

#if canImport(Combine)
  extension QuerySubscription: Subscription {
    public func request(_ demand: Subscribers.Demand) {}
  }
#endif
