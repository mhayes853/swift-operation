import ConcurrencyExtras
import Foundation

// MARK: - QueryStore

public final class QueryStore<Value: Sendable>: Sendable {
  private let query: any QueryProtocol<Value>
  private let state: QueryStateStore<Value?>

  public let defaultValue: Value

  init<V>(query: some QueryProtocol<V>, state: QueryStateStore<V?>) where Value == V? {
    self.query = ToOptionalQuery(base: query)
    self.state = unsafeBitCast(state, to: QueryStateStore<Value?>.self)
    self.defaultValue = nil
  }

  init(query: DefaultQuery<some QueryProtocol<Value>>, state: QueryStateStore<Value?>) {
    self.query = query
    self.state = state
    self.defaultValue = query.defaultValue
  }
}

// MARK: - State

extension QueryStore {
  public var value: Value {
    self.state.value ?? self.defaultValue
  }

  public var valueLastUpdatedAt: Date? {
    self.state.valueLastUpdatedAt
  }

  public var valueUpdateCount: Int {
    self.state.valueUpdateCount
  }

  public var isLoading: Bool {
    self.state.isLoading
  }

  public var error: (any Error)? {
    self.state.error
  }

  public var errorLastUpdatedAt: Date? {
    self.state.errorLastUpdatedAt
  }

  public var errorUpdateCount: Int {
    self.state.errorUpdateCount
  }
}

// MARK: - Fetching

extension QueryStore {
  @discardableResult
  public func fetch() async throws -> Value {
    let task = self.state.update { state in
      if let task = state.fetchTask {
        return task
      }
      state.isLoading = true
      let task = Task {
        do {
          let value = try await self.query.fetch(in: QueryContext())
          self.state.update {
            $0.value = value
            $0.valueUpdateCount += 1
            $0.valueLastUpdatedAt = Date()
            $0.error = nil
            $0.isLoading = false
            $0.fetchTask = nil
          }
          return value as Value?
        } catch {
          self.state.update {
            $0.error = error
            $0.errorUpdateCount += 1
            $0.errorLastUpdatedAt = Date()
            $0.isLoading = false
            $0.fetchTask = nil
          }
          throw error
        }
      }
      state.fetchTask = task
      return task
    }
    return try await task.cancellableValue!
  }
}

// MARK: - ToOptionalQuery

private struct ToOptionalQuery<Base: QueryProtocol>: QueryProtocol {
  let base: Base

  var path: QueryPath {
    self.base.path
  }

  func fetch(in context: QueryContext) async throws -> Base.Value? {
    try await self.base.fetch(in: context)
  }
}
