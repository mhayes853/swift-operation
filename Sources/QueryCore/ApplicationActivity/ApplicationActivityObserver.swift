import Foundation

// MARK: - ApplicationActivityObserver

public protocol ApplicationActivityObserver: Sendable {
  func subscribe(_ handler: @escaping @Sendable (Bool) -> Void) -> QuerySubscription
}
