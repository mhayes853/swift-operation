import Dependencies
import Query
import Sharing

// MARK: - MutationKey

extension SharedKey {
  public static func mutation<Mutation: MutationRequest>(
    _ mutation: Mutation,
    client: QueryClient? = nil
  ) -> Self where Self == MutationKey<Mutation.Arguments, Mutation.Value> {
    MutationKey(base: .mutationState(mutation, client: client))
  }

  public static func mutation<Arguments, Value>(
    store: QueryStore<MutationState<Arguments, Value>>
  ) -> Self where Self == MutationKey<Arguments, Value> {
    MutationKey(base: .queryState(store: store))
  }
}

public struct MutationKey<Arguments: Sendable, V: Sendable> {
  let base: QueryStateKey<MutationState<Arguments, V>>
}

extension MutationKey: SharedKey {
  public typealias Value = SharedMutationValue<Arguments, V>

  public var id: MutationKeyID {
    MutationKeyID(inner: self.base.id)
  }

  public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
    self.base.load(
      context: self.baseContext(for: context),
      continuation: LoadContinuation { result in
        continuation.resume(
          with: result.map {
            SharedMutationValue(currentValue: $0?.currentValue, store: self.base.store)
          }
        )
      }
    )
  }

  public func save(
    _ value: Value,
    context: SaveContext,
    continuation: SaveContinuation
  ) {
    self.base.store.currentValue = value.currentValue
    continuation.resume()
  }

  public func subscribe(
    context: LoadContext<Value>,
    subscriber: SharedSubscriber<Value>
  ) -> SharedSubscription {
    self.base.subscribe(
      context: self.baseContext(for: context),
      subscriber: SharedSubscriber { result in
        subscriber.yield(
          with: result.map {
            SharedMutationValue(currentValue: $0?.currentValue, store: self.base.store)
          }
        )
      } onLoading: {
        subscriber.yieldLoading($0)
      }
    )
  }

  private func baseContext(
    for context: LoadContext<Value>
  ) -> LoadContext<MutationState<Arguments, V>> {
    switch context {
    case .initialValue: .initialValue(self.base.store.state)
    case .userInitiated: .userInitiated
    }
  }
}

// MARK: - MutationKeyID

public struct MutationKeyID: Hashable, Sendable {
  fileprivate let inner: QueryStateKeyID
}

// MARK: - SharedMutationValue

@dynamicMemberLookup
public struct SharedMutationValue<Arguments: Sendable, Value: Sendable>: Sendable {
  public var currentValue: Value?
  private let store: QueryStore<MutationState<Arguments, Value>>

  fileprivate init(currentValue: Value?, store: QueryStore<MutationState<Arguments, Value>>) {
    self.store = store
    self.currentValue = currentValue
  }
}

extension SharedMutationValue {
  public subscript<NewValue>(dynamicMember keyPath: KeyPath<Value, NewValue>) -> NewValue? {
    self.currentValue?[keyPath: keyPath]
  }

  @_disfavoredOverload
  public subscript<NewValue>(dynamicMember keyPath: WritableKeyPath<Value, NewValue>) -> NewValue {
    @available(*, unavailable)
    get { fatalError() }
    set { self.currentValue?[keyPath: keyPath] = newValue }
  }
}

extension SharedMutationValue {
  @discardableResult
  public func mutate(
    with arguments: Arguments,
    using configuration: QueryTaskConfiguration? = nil
  ) async throws -> Value {
    try await self.store.mutate(with: arguments, using: configuration)
  }

  public func mutateTask(
    with arguments: Arguments,
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<Value> {
    self.store.mutateTask(with: arguments, using: configuration)
  }
}

extension SharedMutationValue {
  @discardableResult
  public func retryLatest(
    using configuration: QueryTaskConfiguration? = nil
  ) async throws -> Value {
    try await self.store.retryLatest(using: configuration)
  }

  public func retryLatestTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<Value> {
    self.store.retryLatestTask(using: configuration)
  }
}

extension SharedMutationValue: Equatable where Value: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.currentValue == rhs.currentValue
  }
}

extension SharedMutationValue: Hashable where Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.currentValue)
  }
}

// MARK: - Shared Inits

extension Shared {
  public init<Arguments, V>(_ key: MutationKey<Arguments, V>)
  where Value == SharedMutationValue<Arguments, V> {
    self.init(
      wrappedValue: SharedMutationValue(
        currentValue: key.base.store.currentValue,
        store: key.base.store
      ),
      key
    )
  }
}

extension SharedReader {
  public init<Arguments, V>(_ key: MutationKey<Arguments, V>)
  where Value == SharedMutationValue<Arguments, V> {
    self.init(
      wrappedValue: SharedMutationValue(
        currentValue: key.base.store.currentValue,
        store: key.base.store
      ),
      key
    )
  }
}
