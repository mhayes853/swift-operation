extension OperationRequest where Value: Sendable {
  /// Deduplicates fetches to this query.
  ///
  /// When 2 fetches on this query occur at the same time, the second fetch will not invoke this
  /// query, but rather wait for the result of the first fetch.
  ///
  /// - Returns: A ``ModifiedOperation``.
  public func deduplicated() -> ModifiedOperation<Self, _DeduplicationModifier<Self>> {
    if let query = self as? any PaginatedRequest {
      func open<Query: PaginatedRequest>(query: Query) -> _DeduplicationModifier<Self> {
        _DeduplicationModifier { removeDuplicatePaginatedRequests($0, $1, Query.State.self) }
      }
      return self.modifier(open(query: query))
    } else {
      return self.deduplicated { _, _ in true }
    }
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
  Operation: OperationRequest
>: OperationModifier, Sendable where Operation.Value: Sendable {
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
    let (shouldRun, taskId) = await storage.runAction(for: context)
    guard shouldRun else { return try await storage.wait(for: taskId) }

    var result: Result<Operation.Value, Operation.Failure>
    do {
      result = .success(
        try await operation.run(isolation: isolation, in: context, with: continuation)
      )
    } catch {
      result = .failure(error)
    }

    await storage.send(result: result, for: taskId)
    return try result.get()
  }
}

// MARK: - DeduplicationStorage

private final actor DeduplicationStorage<Operation: OperationRequest>
where Operation.Value: Sendable {
  private struct Entry {
    var waiters = 0
    var result: Result<Operation.Value, any Error>?
    var continuations = [UnsafeContinuation<Operation.Value, any Error>]()
  }

  private let removeDuplicates: @Sendable (OperationContext, OperationContext) -> Bool

  private var currentId = 0
  private var contexts = [(taskId: Int, context: OperationContext)]()
  private var entries = [Int: Entry]()

  init(removeDuplicates: @escaping @Sendable (OperationContext, OperationContext) -> Bool) {
    self.removeDuplicates = removeDuplicates
  }

  func runAction(for context: OperationContext) -> (shouldRun: Bool, taskId: Int) {
    let activeContext = self.contexts.first { self.removeDuplicates($0.context, context) }
    if let activeContext {
      self.entries[activeContext.taskId, default: Entry()].waiters += 1
      return (false, activeContext.taskId)
    }

    defer { self.currentId += 1 }
    self.contexts.append((taskId: self.currentId, context: context))
    return (true, self.currentId)
  }

  func send(result: Result<Operation.Value, Operation.Failure>, for taskId: Int) {
    self.contexts.removeAll { $0.taskId == taskId }
    guard var entry = self.entries[taskId] else { return }
    let newResult = result.mapError { $0 as any Error }
    entry.continuations.forEach { $0.resume(with: newResult) }
    entry.continuations.removeAll()
    entry.result = newResult
    self.entries[taskId] = entry
  }

  func wait(for taskId: Int) async throws(Operation.Failure) -> Operation.Value {
    defer {
      self.entries[taskId]?.waiters -= 1
      if self.entries[taskId]?.waiters == 0 {
        self.entries.removeValue(forKey: taskId)
      }
    }
    do {
      if let result = self.entries[taskId]?.result {
        return try result.get()
      }
      return try await withUnsafeThrowingContinuation { continuation in
        self.entries[taskId]?.continuations.append(continuation)
      }
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
