// MARK: - QueryStoreSubscription

public struct QuerySubscription: Sendable {
  private let storage: Storage

  private init(storage: Storage) {
    self.storage = storage
  }
}

// MARK: - Closure Init

extension QuerySubscription {
  public init(onCancel: @Sendable @escaping () -> Void) {
    self.init(storage: .box(Box(onCancel: onCancel)))
  }
}

// MARK: - Combined

extension QuerySubscription {
  public static func combined(_ subscriptions: [QuerySubscription]) -> QuerySubscription {
    QuerySubscription(storage: .combined(subscriptions))
  }

  public static func combined(_ subscriptions: QuerySubscription...) -> QuerySubscription {
    QuerySubscription(storage: .combined(subscriptions))
  }
}

// MARK: - Empty

extension QuerySubscription {
  public static let empty = QuerySubscription(storage: .empty)
}

// MARK: - Cancel

extension QuerySubscription {
  public func cancel() {
    switch self.storage {
    case .empty:
      break
    case let .box(box):
      box.cancel()
    case let .combined(subscriptions):
      subscriptions.forEach { $0.cancel() }
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
    switch (lhs.storage, rhs.storage) {
    case (.empty, .empty):
      return true
    case let (.box(lhsBox), .box(rhsBox)):
      return lhsBox === rhsBox
    case let (.combined(lhsSubs), .combined(rhsSubs)):
      return lhsSubs == rhsSubs
    default:
      return false
    }
  }
}

// MARK: - Hashable

extension QuerySubscription: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self.storage {
    case .empty:
      break
    case let .box(box):
      hasher.combine(ObjectIdentifier(box))
    case let .combined(subscriptions):
      hasher.combine(subscriptions)
    }
  }
}

// MARK: - Storage

extension QuerySubscription {
  private enum Storage: Sendable {
    case empty
    case box(Box)
    case combined([QuerySubscription])
  }
}

// MARK: - Box

extension QuerySubscription {
  private final class Box: Sendable {
    let onCancel: Lock<(@Sendable () -> Void)?>

    init(onCancel: @escaping @Sendable () -> Void) {
      self.onCancel = Lock(onCancel)
    }

    deinit { self.cancel() }

    func cancel() {
      self.onCancel.withLock { cancel in
        defer { cancel = nil }
        cancel?()
      }
    }
  }
}
