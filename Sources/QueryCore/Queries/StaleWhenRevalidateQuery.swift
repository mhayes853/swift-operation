import Foundation

// MARK: - StaleWhenRevalidateQuery

extension QueryRequest {
  public func staleWhen(
    predicate: @escaping @Sendable (State, QueryContext) -> Bool
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(StaleWhenRevalidateModifier(predicate: predicate))
  }

  public func staleWhen(
    condition: some FetchCondition
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(
      StaleWhenRevalidateModifier { _, context in condition.isSatisfied(in: context) }
    )
  }

  public func stale(after seconds: TimeInterval) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(
      StaleWhenRevalidateModifier { state, context in
        guard let date = state.valueLastUpdatedAt else { return true }
        let now = context.queryClock.now()
        return now.timeIntervalSince(date) > seconds
      }
    )
  }
}

private struct StaleWhenRevalidateModifier<Query: QueryRequest>: QueryModifier {
  let predicate: @Sendable (Query.State, QueryContext) -> Bool

  func setup(context: inout QueryContext, using query: Query) {
    context.staleWhenRevalidateCondition.add { state, context in
      guard let state = state.base as? Query.State else {
        return false
      }
      return predicate(state, context)
    }
    query.setup(context: &context)
  }

  func fetch(
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
    var current = self.predicates.first?(opaqueState, context) ?? true
    for predicate in self.predicates.dropFirst() {
      current = predicate(opaqueState, context)
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
