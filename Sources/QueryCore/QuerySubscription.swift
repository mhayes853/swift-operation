// MARK: - QueryStoreSubscription

/// A type that the library uses for managing subscriptions to data sources.
///
/// This type is akin to `AnyCancellable` from Combine, but it provides a few optimized usage and
/// equality tools.
///
/// For instance, if you need to return a subscription that performs no logic when
/// cancelled, use ``QuerySubscription/empty``.
///
/// ```swift
/// let badSubscription = QuerySubscription {} // 🔴
/// let goodSubscripition = QuerySubscription.empty // ✅
/// ```
///
/// Additionally, you may return a subscription that will cancel other subscriptions when
/// cancelled. You can use ``QuerySubscription/combined(_:)-(QuerySubscription...)`` to optimize this. In addition, using
/// `combined` will also make equality and hashability checks more reliable.
///
/// ```swift
/// let s1 = QuerySubscription { /* ... */ }
/// let s2 = QuerySubscription { /* ... */ }
///
/// // 🔴
/// let badSubscription = QuerySubscription {
///  s1.cancel()
///  s2.cancel()
/// }
///
/// #expect(badSubscription == .combined(s1, s2)) // 🔴 False
///
/// // ✅
/// let goodSubscripition = QuerySubscription.combined(s1, s2)
///
/// #expect(goodSubscription == .combined(s1, s2)) // ✅ True
/// ```
///
/// A subscription is automatically deallocated when cancelled. Therefore, make sure you hold a
/// strong reference to a subscription for the duration of its usage.
public struct QuerySubscription: Sendable {
  private let storage: Storage

  private init(storage: Storage) {
    self.storage = storage
  }
}

// MARK: - Closure Init

extension QuerySubscription {
  /// Creates a subscription with a closure that runs when the subscription is cancelled.
  ///
  /// The specified closure will only be ran 1 time at most.
  ///
  /// Do not use this initializer to create subscriptions that perform no work. Use ``empty``
  /// instead.
  ///
  /// Do not use this intitializer to create subscriptions that cancel a collection of
  /// subscriptions. Use ``QuerySubscription/combined(_:)-(QuerySubscription...)`` instead.
  ///
  /// - Parameter onCancel: A closure that runs when ``cancel()`` is invoked.
  public init(onCancel: @Sendable @escaping () -> Void) {
    self.init(storage: .box(Box(onCancel: onCancel)))
  }
}

// MARK: - Combined

extension QuerySubscription {
  /// Combines an array of subscriptions into a single subscription.
  public static func combined(
    _ subscriptions: some Collection<QuerySubscription>
  ) -> QuerySubscription {
    QuerySubscription(storage: .combined(Array(subscriptions)))
  }

  /// Combines a variadic list of subscriptions into a single subscription.
  public static func combined(_ subscriptions: QuerySubscription...) -> QuerySubscription {
    QuerySubscription(storage: .combined(subscriptions))
  }
}

// MARK: - Empty

extension QuerySubscription {
  /// A subscription that performs no work when cancelled.
  public static let empty = QuerySubscription(storage: .empty)
}

// MARK: - Cancel

extension QuerySubscription {
  /// Cancels this subscription.
  ///
  /// Invoking this method multiple times will have no effect after the first invocation.
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
  /// Stores this subscription in a set of subscriptions.
  ///
  /// You can use this method to retain a strong reference to the subscription in a convenient
  /// manner.
  ///
  /// ```swift
  /// final class Observer {
  ///   var subscriptions = Set<QuerySubscription>()
  ///
  ///   init(store: QueryStore<MyQuery.State>) {
  ///     store.subscribe(
  ///       with: QueryEventHandler { state, context in
  ///         // ...
  ///       }
  ///     )
  ///     .store(in: &subscriptions)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter set: The set to store the subscription in.
  public func store(in set: inout Set<QuerySubscription>) {
    set.insert(self)
  }

  /// Stores this subscription in a collection of subscriptions.
  ///
  /// You can use this method to retain a strong reference to the subscription in a convenient
  /// manner.
  ///
  /// ```swift
  /// final class Observer {
  ///   var subscriptions = [QuerySubscription]()
  ///
  ///   init(store: QueryStore<MyQuery.State>) {
  ///     store.subscribe(
  ///       with: QueryEventHandler { state, context in
  ///         // ...
  ///       }
  ///     )
  ///     .store(in: &subscriptions)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter collection: The collection to store the subscription in.
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
