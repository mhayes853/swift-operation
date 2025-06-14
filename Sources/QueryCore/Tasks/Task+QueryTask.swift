extension Task {
  @discardableResult
  init(
    configuration: QueryTaskConfiguration,
    @_inheritActorContext @_implicitSelfCapture operation:
      sending @escaping @isolated(any) () async throws -> Success
  ) where Failure == Error {
    // TODO: - Use Task name API when it decides to work with executor preferences...
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
