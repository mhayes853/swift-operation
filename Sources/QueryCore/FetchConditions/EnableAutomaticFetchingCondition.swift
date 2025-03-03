// Automatic Fetching:
// 1. Fetching on first subscription
// 2. Fetching on observering condition (eg. Network comes back online)

public struct EnableStoreAutomaticFetchingCondition: Sendable {
  private let storage: Storage

  private init(_ storage: Storage) {
    self.storage = storage
  }
}

extension EnableStoreAutomaticFetchingCondition {
  public static let firstSubscribedTo = Self(.firstSubscribedTo)
  public static let fetchManuallyCalled = Self(.fetchManuallyCalled)
}

extension EnableStoreAutomaticFetchingCondition {
  public var isEnabledByDefault: Bool {
    switch self.storage {
    case .firstSubscribedTo: true
    case .fetchManuallyCalled: false
    }
  }
}

extension EnableStoreAutomaticFetchingCondition {
  private enum Storage: Equatable {
    case firstSubscribedTo
    case fetchManuallyCalled
  }
}
