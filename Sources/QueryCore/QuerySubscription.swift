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
