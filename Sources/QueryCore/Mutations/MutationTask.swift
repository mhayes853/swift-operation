// MARK: - MutationTask

public struct MutationTask<Value: Sendable>: Sendable {
  let inner: QueryTask<Value>
}

// MARK: - Context

extension MutationTask {
  public var context: QueryContext {
    self.inner.context
  }
}

// MARK: - Value

extension MutationTask {
  public var value: Value {
    get async throws { try await self.inner.runIfNeeded() }
  }
}

// MARK: - Identifiable

extension MutationTask: Identifiable {
  public var id: MutationTaskID {
    MutationTaskID(inner: self.inner.id)
  }
}

// MARK: - MutationTaskID

public struct MutationTaskID: Hashable, Sendable {
  let inner: QueryTaskID
}

// MARK: - Hashable

extension MutationTask: Hashable {}
