// MARK: - QueryTaskConfiguration

/// A configuration data type for a ``QueryTask`` that holds information on how the task runs, and
/// the ``QueryContext`` used to run the task.
public struct QueryTaskConfiguration: Sendable {
  /// The name of the task.
  public var name: String?

  /// The priority of the underlying raw `Task` value used by the task.
  public var priority: TaskPriority?

  /// The ``QueryContext`` of the task.
  public var context: QueryContext

  private var _executorPreference: (any Sendable)?

  /// Creates a task configuration.
  ///
  /// - Parameters:
  ///   - name: The name of the task.
  ///   - priority: The priority of the underlying raw `Task` value used by the task.
  public init(
    name: String? = nil,
    priority: TaskPriority? = nil,
    context: QueryContext = QueryContext()
  ) {
    self.name = name
    self.priority = priority
    self.context = context
    self._executorPreference = nil
  }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension QueryTaskConfiguration {
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
    executorPreference: (any TaskExecutor)? = nil,
    context: QueryContext = QueryContext()
  ) {
    self.name = name
    self.priority = priority
    self._executorPreference = executorPreference
    self.context = context
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var queryTaskConfiguration: QueryTaskConfiguration {
    get { self[QueryTaskConfigurationKey.self] }
    set { self[QueryTaskConfigurationKey.self] = newValue }
  }

  private enum QueryTaskConfigurationKey: Key {
    static var defaultValue: QueryTaskConfiguration {
      QueryTaskConfiguration()
    }
  }
}
