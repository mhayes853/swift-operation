// MARK: - QueryEnableAutomaticFetchingCondition

public struct EnableAutomaticFetchingCondition: Sendable {
  private let storage: Storage

  private init(_ storage: Storage) {
    self.storage = storage
  }
}

extension EnableAutomaticFetchingCondition {
  public static let firstSubscribedTo = Self(.firstSubscribedTo)
  public static let fetchManuallyCalled = Self(.fetchManuallyCalled)
}

extension EnableAutomaticFetchingCondition {
  public var isEnabledByDefault: Bool {
    switch self.storage {
    case .firstSubscribedTo: true
    case .fetchManuallyCalled: false
    }
  }
}

extension EnableAutomaticFetchingCondition {
  private enum Storage: Equatable {
    case firstSubscribedTo
    case fetchManuallyCalled
  }
}

// MARK: - QueryProtocol

extension QueryProtocol {
  public func enableAutomaticFetching(
    when condition: EnableAutomaticFetchingCondition
  ) -> ModifiedQuery<Self, _EnableAutomaticFetchingModifier<Self>> {
    self.modifier(_EnableAutomaticFetchingModifier(condition: condition))
  }
}

public struct _EnableAutomaticFetchingModifier<Query: QueryProtocol>: QueryModifier {
  let condition: EnableAutomaticFetchingCondition

  public func _setup(context: inout QueryContext, using query: Query) {
    context.enableAutomaticFetchingCondition = self.condition
    query._setup(context: &context)
  }

  public func fetch(in context: QueryContext, using query: Query) async throws -> Query.Value {
    try await query.fetch(in: context)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public fileprivate(set) var enableAutomaticFetchingCondition: EnableAutomaticFetchingCondition {
    get { self[EnableAutomaticFetchingKey.self] }
    set { self[EnableAutomaticFetchingKey.self] = newValue }
  }

  private enum EnableAutomaticFetchingKey: Key {
    static let defaultValue = EnableAutomaticFetchingCondition.firstSubscribedTo
  }
}
