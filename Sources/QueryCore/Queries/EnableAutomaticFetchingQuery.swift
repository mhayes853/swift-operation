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
  ) -> some QueryProtocol<Value> {
    EnableAutomaticFetchingQuery(base: self, condition: condition)
  }
}

private struct EnableAutomaticFetchingQuery<Base: QueryProtocol>: QueryProtocol {
  let base: Base
  let condition: EnableAutomaticFetchingCondition

  var path: QueryPath {
    self.base.path
  }

  func _setup(context: inout QueryContext) {
    context.enableAutomaticFetchingCondition = self.condition
    self.base._setup(context: &context)
  }

  func fetch(in context: QueryContext, currentValue: Base.StateValue) async throws -> Base.Value {
    try await self.base.fetch(in: context, currentValue: currentValue)
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
