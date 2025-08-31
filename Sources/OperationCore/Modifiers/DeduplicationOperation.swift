extension OperationRequest where Self: Sendable {
  /// Deduplicates fetches to this query.
  ///
  /// When 2 fetches on this query occur at the same time, the second fetch will not invoke this
  /// query, but rather wait for the result of the first fetch.
  ///
  /// - Returns: A ``ModifiedOperation``.
  public func deduplicated() -> ModifiedOperation<Self, _DeduplicationModifier<Self>> {
    self.modifier(
      _DeduplicationModifier { i1, i2 in
        if let query = self as? any InfiniteQueryRequest {
          return removeDuplicateInfiniteQueries(i1, i2, using: query)
        } else {
          return true
        }
      }
    )
  }

  /// Deduplicates fetches to this query based on a predicate.
  ///
  /// When 2 fetches on this query occur at the same time, the second fetch will not invoke this
  /// query, but rather wait for the result of the first fetch.
  ///
  /// - Parameter removeDuplicates: A predicate to distinguish duplicate fetch attempts.
  /// - Returns: A ``ModifiedOperation``.
  public func deduplicated(
    by removeDuplicates: @escaping @Sendable (OperationContext, OperationContext) -> Bool
  ) -> ModifiedOperation<Self, _DeduplicationModifier<Self>> {
    self.modifier(_DeduplicationModifier(removeDuplicates: removeDuplicates))
  }
}

public struct _DeduplicationModifier<
  Operation: OperationRequest & Sendable
>: OperationModifier, Sendable {
  private let removeDuplicates: @Sendable (OperationContext, OperationContext) -> Bool

  init(removeDuplicates: @escaping @Sendable (OperationContext, OperationContext) -> Bool) {
    self.removeDuplicates = removeDuplicates
  }

  public func setup(context: inout OperationContext, using operation: Operation) {
    context.deduplicationStorage = DeduplicationStorage<Operation>(
      removeDuplicates: self.removeDuplicates
    )
    operation.setup(context: &context)
  }

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using operation: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    guard let storage = context.deduplicationStorage as? DeduplicationStorage<Operation> else {
      return try await operation.run(isolation: isolation, in: context, with: continuation)
    }
    return try await storage.run(operation: operation, in: context, with: continuation)
  }
}

// MARK: - DeduplicationStorage

private final actor DeduplicationStorage<Operation: OperationRequest & Sendable> {
  private let removeDuplicates: @Sendable (OperationContext, OperationContext) -> Bool

  private var idCounter = 0
  private var entries = [
    (id: Int, context: OperationContext, task: Task<Operation.Value, any Error>)
  ]()

  init(removeDuplicates: @escaping @Sendable (OperationContext, OperationContext) -> Bool) {
    self.removeDuplicates = removeDuplicates
  }

  func run(
    operation: Operation,
    in context: OperationContext,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    if let task = self.task(for: context) {
      return try await self.waitForTask(task)
    }
    defer { self.idCounter += 1 }
    let id = self.idCounter
    let task = Task {
      defer { self.entries.removeAll { $0.id == id } }
      return try await operation.run(isolation: self, in: context, with: continuation)
    }
    self.entries.append((id, context, task))
    return try await self.waitForTask(task)
  }

  private func task(for context: OperationContext) -> Task<Operation.Value, any Error>? {
    self.entries.first(where: { self.removeDuplicates($0.context, context) })?.task
  }

  private func waitForTask(
    _ task: Task<Operation.Value, any Error>
  ) async throws(Operation.Failure) -> Operation.Value {
    do {
      return try await task.cancellableValue
    } catch {
      throw error as! Operation.Failure
    }
  }
}

// MARK: - OperationContext

extension OperationContext {
  fileprivate var deduplicationStorage: (any Sendable)? {
    get { self[DeduplicationStorageKey.self] }
    set { self[DeduplicationStorageKey.self] = newValue }
  }

  private enum DeduplicationStorageKey: Key {
    static let defaultValue: (any Sendable)? = nil
  }
}
