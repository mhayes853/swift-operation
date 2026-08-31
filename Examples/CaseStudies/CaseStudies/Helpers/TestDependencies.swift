#if DEBUG
  import Dependencies

  // Operation work is created from the app target. Entering the scope here ensures that app code
  // observes the overrides used by the test.
  func withCaseStudiesDependencies<R>(
    _ updateValues: (inout DependencyValues) async throws -> Void,
    operation: () async throws -> R
  ) async rethrows -> R {
    try await withDependencies(updateValues, operation: operation)
  }
#endif
