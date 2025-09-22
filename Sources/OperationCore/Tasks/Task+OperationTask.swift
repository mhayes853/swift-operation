extension Task {
  /// Runs the given throwing operation asynchronously as part of a new unstructured top-level task.
  ///
  /// - Parameters:
  ///   - configuration: An ``OperationTaskConfiguration``.
  ///   - operation: The operation to perform.
  @discardableResult
  public init(
    configuration: OperationTaskConfiguration,
    @_inheritActorContext @_implicitSelfCapture operation:
      sending @escaping @isolated(any) () async throws -> Success
  ) where Failure == any Error {
    #if swift(>=6.2)
      if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *),
        // NB: Avoid passing nil to executorPreference to avoid crashing.
        let executor = configuration.executorPreference
      {
        self.init(
          name: configuration.name,
          executorPreference: executor,
          priority: configuration.priority,
          operation: operation
        )
      } else {
        self.init(
          name: configuration.name,
          priority: configuration.priority,
          operation: operation
        )
      }
    #else
      if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
        self.init(
          executorPreference: configuration.executorPreference,
          priority: configuration.priority,
          operation: operation
        )
      } else {
        self.init(priority: configuration.priority, operation: operation)
      }
    #endif
  }

  /// Runs the given nonthrowing operation asynchronously as part of a new unstructured top-level task.
  ///
  /// - Parameters:
  ///   - configuration: An ``OperationTaskConfiguration``.
  ///   - operation: The operation to perform.
  @discardableResult
  public init(
    configuration: OperationTaskConfiguration,
    @_inheritActorContext @_implicitSelfCapture operation:
      sending @escaping @isolated(any) () async -> Success
  ) where Failure == Never {
    #if swift(>=6.2)
      if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *),
        // NB: Avoid passing nil to executorPreference to avoid crashing.
        let executor = configuration.executorPreference
      {
        self.init(
          name: configuration.name,
          executorPreference: executor,
          priority: configuration.priority,
          operation: operation
        )
      } else {
        self.init(
          name: configuration.name,
          priority: configuration.priority,
          operation: operation
        )
      }
    #else
      if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
        self.init(
          executorPreference: configuration.executorPreference,
          priority: configuration.priority,
          operation: operation
        )
      } else {
        self.init(priority: configuration.priority, operation: operation)
      }
    #endif
  }
}
