import Foundation

// MARK: - StaleWhenRevalidateQuery

extension QueryRequest {
  /// Marks ``QueryStore/isStale`` as true for this query whenever the specified predicate is true.
  ///
  /// Chaining multiple instances of any modifier that begins with `stale` will result in an OR
  /// operation being applied between the diffent conditions. For instance, the following queries
  /// are equivalent:
  ///
  /// ```swift
  /// let q1 = MyQuery().staleWhen { state, _ in state.currentValue.isMultiple(of: 3) }
  ///   .staleWhen { state, _ in state.currentValue.isMultiple(of: 2) }
  ///
  /// let q2 = MyQuery().staleWhen { state, _ in
  ///   state.currentValue.isMultiple(of: 3) || state.currentValue.isMultiple(of: 2)
  /// }
  /// ```
  ///
  /// - Parameter predicate: A predicate to evaluate whether or not ``QueryStore/isStale`` is true.
  /// - Returns: A ``ModifiedQuery``.
  public func staleWhen(
    predicate: @escaping @Sendable (State, QueryContext) -> Bool
  ) -> ModifiedQuery<Self, _StaleWhenModifier<Self>> {
    self.modifier(_StaleWhenModifier(predicate: predicate))
  }

  /// Marks ``QueryStore/isStale`` as true for this query whenever the specified ``FetchCondition`` is true.
  ///
  /// Chaining multiple instances of any modifier that begins with `stale` will result in an OR
  /// operation being applied between the diffent conditions. For instance, the following queries
  /// are equivalent:
  ///
  /// ```swift
  /// let q1 = MyQuery().staleWhen(condition: cond1)
  ///   .staleWhen(condition: cond2)
  ///
  /// let q2 = MyQuery().staleWhen(condition: cond1 || cond2)
  /// ```
  ///
  /// - Parameter condition: A ``FetchCondition`` to indicate whether or not ``QueryStore/isStale`` is true.
  /// - Returns: A ``ModifiedQuery``.
  public func staleWhen(
    condition: some FetchCondition
  ) -> ModifiedQuery<Self, _StaleWhenModifier<Self>> {
    self.modifier(
      _StaleWhenModifier { _, context in condition.isSatisfied(in: context) }
    )
  }

  /// Marks ``QueryStore/isStale`` as true for this query whenever its current value is nil.
  ///
  /// Chaining multiple instances of any modifier that begins with `stale` will result in an OR
  /// operation being applied between the diffent conditions. For instance, the following queries
  /// are equivalent:
  ///
  /// ```swift
  /// let q1 = MyQuery().staleWhenNoValue()
  ///   .staleWhen { state, _ in state.currentValue == 1 }
  ///
  /// let q2 = MyQuery().staleWhen { state, _ in
  ///   state.currentValue == nil || state.currentValue == 1
  /// }
  /// ```
  ///
  /// - Returns: A ``ModifiedQuery``.
  public func staleWhenNoValue() -> ModifiedQuery<Self, _StaleWhenModifier<Self>>
  where State.StateValue == Value? {
    self.staleWhen { state, _ in state.currentValue == nil }
  }

  /// Marks ``QueryStore/isStale`` as true for this query when the specified number of seconds has
  /// elapsed since the last time this query was successfully fetched..
  ///
  /// Chaining multiple instances of any modifier that begins with `stale` will result in an OR
  /// operation being applied between the diffent conditions. For instance:
  ///
  /// ```swift
  /// // This query is stale whenever 5 minutes have elapsed since its last
  /// // successful fetch, OR when its current value is 1.
  /// let query = MyQuery().stale(after: fiveMinutes)
  ///   .staleWhen { state, _ in state.currentValue == 1 }
  /// ```
  ///
  /// - Parameter seconds: A `TimeInterval` at which ``QueryStore/isStale`` is true after a successful fetch.
  /// - Returns: A ``ModifiedQuery``.
  public func stale(after seconds: TimeInterval) -> ModifiedQuery<Self, _StaleWhenModifier<Self>> {
    self.modifier(
      _StaleWhenModifier { state, context in
        guard let date = state.valueLastUpdatedAt else { return true }
        let now = context.queryClock.now()
        return now.timeIntervalSince(date) > seconds
      }
    )
  }
}

public struct _StaleWhenModifier<Query: QueryRequest>: QueryModifier {
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
