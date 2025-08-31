import Foundation

// MARK: - StaleWhenRevalidateQuery

extension OperationRequest {
  /// Marks ``OperationStore/isStale`` as true for this query whenever the specified predicate is true.
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
  /// - Parameter predicate: A predicate to evaluate whether or not ``OperationStore/isStale`` is true.
  /// - Returns: A ``ModifiedOperation``.
  public func staleWhen(
    predicate: @escaping @Sendable (State, OperationContext) -> Bool
  ) -> ModifiedOperation<Self, _StaleWhenModifier<Self>> {
    self.modifier(_StaleWhenModifier(predicate: predicate))
  }

  /// Marks ``OperationStore/isStale`` as true for this query whenever the specified ``FetchCondition`` is true.
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
  /// - Parameter condition: A ``FetchCondition`` to indicate whether or not ``OperationStore/isStale`` is true.
  /// - Returns: A ``ModifiedOperation``.
  public func staleWhen(
    satisfying specification: some OperationRunSpecification & Sendable
  ) -> ModifiedOperation<Self, _StaleWhenModifier<Self>> {
    self.modifier(
      _StaleWhenModifier { _, context in specification.isSatisfied(in: context) }
    )
  }

  /// Marks ``OperationStore/isStale`` as true for this query whenever its current value is nil.
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
  /// - Returns: A ``ModifiedOperation``.
  public func staleWhenNoValue() -> ModifiedOperation<Self, _StaleWhenModifier<Self>>
  where State.StateValue == Value? {
    self.staleWhen { state, _ in state.currentValue == nil }
  }

  /// Marks ``OperationStore/isStale`` as true for this query when the specified number of seconds has
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
  /// - Parameter seconds: A `TimeInterval` at which ``OperationStore/isStale`` is true after a successful fetch.
  /// - Returns: A ``ModifiedOperation``.
  public func stale(
    after seconds: TimeInterval
  ) -> ModifiedOperation<Self, _StaleWhenModifier<Self>> {
    self.modifier(
      _StaleWhenModifier { state, context in
        guard let date = state.valueLastUpdatedAt else { return true }
        let now = context.operationClock.now()
        return now.timeIntervalSince(date) > seconds
      }
    )
  }
}

public struct _StaleWhenModifier<
  Operation: OperationRequest
>: _ContextUpdatingOperationModifier, Sendable {
  let predicate: @Sendable (Operation.State, OperationContext) -> Bool

  public func setup(context: inout OperationContext) {
    context.staleWhenRevalidateCondition.add { state, context in
      guard let state = state.base as? Operation.State else {
        return false
      }
      return predicate(state, context)
    }
  }
}

// MARK: - StaleWhenRevalidateCondition

@_spi(StaleWhenRevalidateCondition)
public struct StaleWhenRevalidateCondition: Sendable {
  private var predicates = [@Sendable (OpaqueOperationState, OperationContext) -> Bool]()

  public init() {}

  public mutating func add(
    predicate: @escaping @Sendable (OpaqueOperationState, OperationContext) -> Bool
  ) {
    self.predicates.append(predicate)
  }

  public func evaluate(state: some OperationState, in context: OperationContext) -> Bool {
    let opaqueState = OpaqueOperationState(state)
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

// MARK: - OperationContext

@_spi(StaleWhenRevalidateCondition)
extension OperationContext {
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
