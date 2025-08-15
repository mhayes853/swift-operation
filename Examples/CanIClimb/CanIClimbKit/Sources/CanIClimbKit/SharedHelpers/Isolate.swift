public func isolate<T, E: Error, A: Actor>(
  _ a: A,
  _ fn: @Sendable (isolated A) async throws(E) -> sending T
) async throws(E) -> sending T {
  try await fn(a)
}
