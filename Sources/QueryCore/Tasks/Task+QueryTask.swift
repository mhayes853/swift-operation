extension Task {
  @discardableResult
  init(
    configuration: QueryTaskConfiguration,
    @_inheritActorContext @_implicitSelfCapture operation:
      sending @escaping @isolated(any) () async throws -> Success
  ) where Failure == Error {
    // TODO: - Use the newly proposed task name API when available in swift 6.x.
    if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
      self.init(
        executorPreference: configuration.executorPreference,
        priority: configuration.priority,
        operation: operation
      )
    } else {
      self = Task(priority: configuration.priority, operation: operation)
    }
  }
}
