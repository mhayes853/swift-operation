import Foundation

// MARK: - StaleWhenRevalidateQuery

extension QueryRequest {
  public func staleWhen(
    predicate: @escaping @Sendable (State, QueryContext) -> Bool
  ) -> ModifiedQuery<Self, StaleWhenModifier<Self>> {
    self.modifier(StaleWhenModifier(predicate: predicate))
  }

  public func staleWhen(
    condition: some FetchCondition
  ) -> ModifiedQuery<Self, StaleWhenModifier<Self>> {
    self.modifier(
      StaleWhenModifier { _, context in condition.isSatisfied(in: context) }
    )
  }

  public func staleWhenNoValue() -> ModifiedQuery<Self, StaleWhenModifier<Self>>
  where State.StateValue == Value? {
    self.staleWhen { state, _ in state.currentValue == nil }
  }

  public func stale(after seconds: TimeInterval) -> ModifiedQuery<Self, StaleWhenModifier<Self>> {
    self.modifier(
      StaleWhenModifier { state, context in
        guard let date = state.valueLastUpdatedAt else { return true }
        let now = context.queryClock.now()
        return now.timeIntervalSince(date) > seconds
      }
    )
  }
}

public struct StaleWhenModifier<Query: QueryRequest>: QueryModifier {
  let predicate: @Sendable (Query.State, QueryContext) -> Bool

  public func setup(context: inout QueryContext, using query: Query) {
    context.staleWhenRevalidateCondition.add { state, context in
      guard let state = state.base as? Query.State else {
        return false
      }
      return predicate(state, context)
    }
    query.setup(context: &context)
  }

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await query.fetch(in: context, with: continuation)
  }
}

// MARK: - StaleWhenRevalidateCondition

@_spi(StaleWhenRevalidateCondition)
public struct StaleWhenRevalidateCondition: Sendable {
  private var predicates = [@Sendable (OpaqueQueryState, QueryContext) -> Bool]()

  public init() {}
}

@_spi(StaleWhenRevalidateCondition)
extension StaleWhenRevalidateCondition {
  public mutating func add(
    predicate: @escaping @Sendable (OpaqueQueryState, QueryContext) -> Bool
  ) {
    self.predicates.append(predicate)
  }
}

@_spi(StaleWhenRevalidateCondition)
extension StaleWhenRevalidateCondition {
  public func evaluate(state: some QueryStateProtocol, in context: QueryContext) -> Bool {
    let opaqueState = OpaqueQueryState(state)
    var current = true
    for predicate in self.predicates {
      current = predicate(opaqueState, context)
      if current {
        return current
      }
    }
    return current
  }
}

// MARK: - QueryContext

@_spi(StaleWhenRevalidateCondition)
extension QueryContext {
  public var staleWhenRevalidateCondition: StaleWhenRevalidateCondition {
    get { self[StaleWhenRevalidateConditionKey.self] }
    set { self[StaleWhenRevalidateConditionKey.self] = newValue }
  }

  private enum StaleWhenRevalidateConditionKey: Key {
    static var defaultValue: StaleWhenRevalidateCondition {
      StaleWhenRevalidateCondition()
    }
  }
}
