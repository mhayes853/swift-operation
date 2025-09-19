// MARK: - OperationStoreSubscription

/// A type that the library uses for managing subscriptions to data sources.
///
/// This type is akin to `AnyCancellable` from Combine, but it provides a few optimized usage and
/// equality tools.
///
/// You can create a subscription with a closure that runs when ``cancel()`` is called.
///
/// ```swift
/// let subscription = OperationSubscription {
///   print("Cancelled, performing cleanup work!")
/// }
/// ```
///
/// The above closure is guaranteed to be invoked at most a single time, so you do not need to
/// consider the case where cancellation is invoked more than once.
///
/// If you need to return a subscription that performs no logic when cancelled, use
/// ``OperationSubscription/empty``.
///
/// ```swift
/// let badSubscription = OperationSubscription {} // 🔴
/// let goodSubscripition = OperationSubscription.empty // ✅
/// ```
///
/// Additionally, you may return a subscription that will cancel other subscriptions when
/// cancelled. You can use ``OperationSubscription/combined(_:)-(OperationSubscription...)`` to
/// optimize this. In addition, using `combined` will also make equality and hashability checks more reliable.
///
/// ```swift
/// let s1 = OperationSubscription { /* ... */ }
/// let s2 = OperationSubscription { /* ... */ }
///
/// // 🔴
/// let badSubscription = OperationSubscription {
///  s1.cancel()
///  s2.cancel()
/// }
///
/// #expect(badSubscription == .combined(s1, s2)) // 🔴 False
///
/// // ✅
/// let goodSubscripition = OperationSubscription.combined(s1, s2)
///
/// #expect(goodSubscription == .combined(s1, s2)) // ✅ True
/// ```
///
/// A subscription is automatically deallocated when cancelled. Therefore, make sure you hold a
/// strong reference to a subscription for the duration of its usage.
public struct OperationSubscription: Sendable {
  private let storage: Storage

  private init(storage: Storage) {
    self.storage = storage
  }
}

// MARK: - Closure Init

extension OperationSubscription {
  /// Creates a subscription with a closure that runs when the subscription is cancelled.
  ///
  /// The specified closure will only be ran 1 time at most.
  ///
  /// Do not use this initializer to create subscriptions that perform no work. Use ``empty``
  /// instead.
  ///
  /// Do not use this intitializer to create subscriptions that cancel a collection of
  /// subscriptions. Use ``OperationSubscription/combined(_:)-(OperationSubscription...)`` instead.
  ///
  /// - Parameter onCancel: A closure that runs when ``cancel()`` is invoked.
  public init(onCancel: @Sendable @escaping () -> Void) {
    self.init(storage: .box(Box(onCancel: onCancel)))
  }
}

// MARK: - Combined

extension OperationSubscription {
  /// Combines an array of subscriptions into a single subscription.
  public static func combined(
    _ subscriptions: some Collection<OperationSubscription>
  ) -> OperationSubscription {
    OperationSubscription(storage: .combined(Array(subscriptions)))
  }

  /// Combines a variadic list of subscriptions into a single subscription.
  public static func combined(_ subscriptions: OperationSubscription...) -> OperationSubscription {
    OperationSubscription(storage: .combined(subscriptions))
  }
}

// MARK: - Empty

extension OperationSubscription {
  /// A subscription that performs no work when cancelled.
  public static let empty = OperationSubscription(storage: .empty)
}

// MARK: - Cancel

extension OperationSubscription {
  /// Cancels this subscription.
  ///
  /// Invoking this method multiple times will have no effect after the first invocation.
  public func cancel() {
    switch self.storage {
    case .empty:
      break
    case .box(let box):
      box.cancel()
    case .combined(let subscriptions):
      subscriptions.forEach { $0.cancel() }
    }
  }
}

// MARK: - Storing

extension OperationSubscription {
  /// Stores this subscription in a set of subscriptions.
  ///
  /// You can use this method to retain a strong reference to the subscription in a convenient
  /// manner.
  ///
  /// ```swift
  /// final class Observer {
  ///   var subscriptions = Set<OperationSubscription>()
  ///
  ///   init(store: OperationStore<MyQuery.State>) {
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
  public func store(in set: inout Set<OperationSubscription>) {
    set.insert(self)
  }

  /// Stores this subscription in a collection of subscriptions.
  ///
  /// You can use this method to retain a strong reference to the subscription in a convenient
  /// manner.
  ///
  /// ```swift
  /// final class Observer {
  ///   var subscriptions = [OperationSubscription]()
  ///
  ///   init(store: OperationStore<MyQuery.State>) {
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
  public func store(in collection: inout some RangeReplaceableCollection<OperationSubscription>) {
    collection.append(self)
  }
}

// MARK: - Equatable

extension OperationSubscription: Equatable {
  public static func == (lhs: OperationSubscription, rhs: OperationSubscription) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.empty, .empty):
      return true
    case (.box(let lhsBox), .box(let rhsBox)):
      return lhsBox === rhsBox
    case (.combined(let lhsSubs), .combined(let rhsSubs)):
      return lhsSubs == rhsSubs
    default:
      return false
    }
  }
}

// MARK: - Hashable

extension OperationSubscription: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self.storage {
    case .empty:
      break
    case .box(let box):
      hasher.combine(ObjectIdentifier(box))
    case .combined(let subscriptions):
      hasher.combine(subscriptions)
    }
  }
}

// MARK: - Storage

extension OperationSubscription {
  private enum Storage: Sendable {
    case empty
    case box(Box)
    case combined([OperationSubscription])
  }
}

// MARK: - Box

extension OperationSubscription {
  private final class Box: Sendable {
    private let onCancel: Lock<(@Sendable () -> Void)?>

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
