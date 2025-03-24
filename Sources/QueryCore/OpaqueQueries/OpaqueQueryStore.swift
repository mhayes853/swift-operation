import ConcurrencyExtras
import Foundation

// MARK: - QueryStore

@dynamicMemberLookup
public final class OpaqueQueryStore: Sendable {
  private let _base: any OpaqueableQueryStore

  public init(erasing base: QueryStore<some QueryStateProtocol>) {
    self._base = base
  }
}

// MARK: - Base

extension OpaqueQueryStore {
  public var base: any Sendable {
    self._base
  }
}

// MARK: - Path

extension OpaqueQueryStore {
  public var path: QueryPath {
    self._base.path
  }
}

// MARK: - Context

extension OpaqueQueryStore {
  public var context: QueryContext {
    get { self._base.context }
    set { self._base.context = newValue }
  }
}

// MARK: - Automatic Fetching

extension OpaqueQueryStore {
  public var isAutomaticFetchingEnabled: Bool {
    self._base.isAutomaticFetchingEnabled
  }
}

// MARK: - State

extension OpaqueQueryStore {
  public var state: OpaqueQueryState {
    self._base.opaqueState
  }

  public subscript<NewValue: Sendable>(
    dynamicMember keyPath: KeyPath<OpaqueQueryState, NewValue>
  ) -> NewValue {
    self.state[keyPath: keyPath]
  }
}

// MARK: - Reset

extension OpaqueQueryStore {
  public func reset(using context: QueryContext? = nil) {
    self._base.reset(using: context)
  }
}

// MARK: - Fetch

extension OpaqueQueryStore {
  @discardableResult
  public func fetch(
    using configuration: QueryTaskConfiguration? = nil,
    handler: OpaqueQueryEventHandler = OpaqueQueryEventHandler()
  ) async throws -> any Sendable {
    try await self._base.opaqueFetch(using: configuration, handler: handler)
  }

  @discardableResult
  public func fetchTask(
    using configuration: QueryTaskConfiguration? = nil
  ) -> QueryTask<any Sendable> {
    self._base.opaqueFetchTask(using: configuration)
  }
}

// MARK: - Subscribe

extension OpaqueQueryStore {
  public var subscriberCount: Int {
    self._base.subscriberCount
  }

  public func subscribe(with handler: OpaqueQueryEventHandler) -> QuerySubscription {
    self._base.opaqueSubscribe(with: handler)
  }
}

// MARK: - OpaquableQueryStore

private protocol OpaqueableQueryStore: Sendable {
  var opaqueState: OpaqueQueryState { get }
  var isAutomaticFetchingEnabled: Bool { get }
  var path: QueryPath { get }
  var context: QueryContext { get nonmutating set }
  var subscriberCount: Int { get }

  func opaqueFetch(
    using configuration: QueryTaskConfiguration?,
    handler: OpaqueQueryEventHandler
  ) async throws -> any Sendable

  func reset(using context: QueryContext?)

  func opaqueFetchTask(using configuration: QueryTaskConfiguration?) -> QueryTask<any Sendable>

  func opaqueSubscribe(with handler: OpaqueQueryEventHandler) -> QuerySubscription
}

extension QueryStore: OpaqueableQueryStore {
  var opaqueState: OpaqueQueryState { OpaqueQueryState(self.state) }

  func opaqueFetch(
    using configuration: QueryTaskConfiguration?,
    handler: OpaqueQueryEventHandler
  ) async throws -> any Sendable {
    try await self.fetch(using: configuration, handler: handler.casted(to: State.self))
  }

  func opaqueFetchTask(using configuration: QueryTaskConfiguration?) -> QueryTask<any Sendable> {
    self.fetchTask(using: configuration).map { $0 }
  }

  func opaqueSubscribe(with handler: OpaqueQueryEventHandler) -> QuerySubscription {
    self.subscribe(with: handler.casted(to: State.self))
  }
}
