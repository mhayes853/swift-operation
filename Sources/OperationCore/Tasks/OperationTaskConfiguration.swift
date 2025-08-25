// MARK: - OperationTaskConfiguration

/// A configuration data type for a ``OperationTask`` that holds information on how the task runs, and
/// the ``OperationContext`` used to run the task.
public struct OperationTaskConfiguration: Sendable {
  /// The name of the task.
  public var name: String?

  /// The priority of the underlying raw `Task` value used by the task.
  public var priority: TaskPriority?

  private var _executorPreference: (any Sendable)?

  /// Creates a task configuration.
  ///
  /// - Parameters:
  ///   - name: The name of the task.
  ///   - priority: The priority of the underlying raw `Task` value used by the task.
  public init(name: String? = nil, priority: TaskPriority? = nil) {
    self.name = name
    self.priority = priority
    self._executorPreference = nil
  }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension OperationTaskConfiguration {
  /// The `TaskExecutor` preference of the underlying raw `Task` value used by the task.
  public var executorPreference: (any TaskExecutor)? {
    get { self._executorPreference as? any TaskExecutor }
    set { self._executorPreference = newValue }
  }

  /// Creates a task configuration.
  ///
  /// - Parameters:
  ///   - name: The name of the task.
  ///   - priority: The priority of the underlying raw `Task` value used by the task.
  ///   - executorPreference: The `TaskExecutor` preference of the underlying raw `Task` value used by the task.
  public init(
    name: String? = nil,
    priority: TaskPriority? = nil,
    executorPreference: (any TaskExecutor)? = nil
  ) {
    self.name = name
    self.priority = priority
    self._executorPreference = executorPreference
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The ``OperationTaskConfiguration`` to use for a ``OperationTask``.
  ///
  /// The default value is a configuration equivalent to initializing a `OperationTaskConfiguration`
  /// with the default arguments.
  public var operationTaskConfiguration: OperationTaskConfiguration {
    get { self[OperationTaskConfigurationKey.self] }
    set { self[OperationTaskConfigurationKey.self] = newValue }
  }

  private enum OperationTaskConfigurationKey: Key {
    static var defaultValue: OperationTaskConfiguration {
      OperationTaskConfiguration()
    }
  }
}
