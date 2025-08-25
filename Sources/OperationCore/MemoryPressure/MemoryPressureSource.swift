#if canImport(Dispatch)
  import Dispatch
#endif

// MARK: - MemoryPressureSource

/// A protocol for observing memory pressure notifications.
///
/// ``OperationClient/DefaultStoreCache`` uses this protocol to evict inactive stores whenever a new
/// pressure notification is received.
public protocol MemoryPressureSource {
  /// Subcribes to pressure notifications from this source.
  ///
  /// - Parameter handler: A handler to run whenever a new notification is emitted.
  /// - Returns: A ``OperationSubscription``.
  func subscribe(
    with handler: @escaping @Sendable (MemoryPressure) -> Void
  ) -> OperationSubscription
}
