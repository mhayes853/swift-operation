// MARK: - QueryStoreSubscription

public final class QueryStoreSubscription: Sendable {
  private let onCancel: Lock<(@Sendable () -> Void)?>

  init(onCancel: @Sendable @escaping () -> Void) {
    self.onCancel = Lock(onCancel)
  }

  deinit { self.cancel() }
}

// MARK: - Cancel

extension QueryStoreSubscription {
  public func cancel() {
    self.onCancel.withLock { cancel in
      defer { cancel = nil }
      cancel?()
    }
  }
}
