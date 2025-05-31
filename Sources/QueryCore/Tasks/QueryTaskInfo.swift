// MARK: - Info

/// Info about an existing ``QueryTask``.
///
/// You cannot directly create instances of this type. You must get an instance from an existing
/// ``QueryTask``, or you can access the info of a running task from within
/// ``QueryRequest/fetch(in:with:)`` via the ``QueryContext/queryRunningTaskInfo`` context value.
public struct QueryTaskInfo: Sendable, Identifiable {
  public let id: QueryTaskIdentifier

  /// The ``QueryTaskConfiguration`` of the task.
  public var configuration: QueryTaskConfiguration
}

extension QueryTaskInfo: CustomStringConvertible {
  public var description: String {
    "[\(self.configuration.name ?? "Unnamed QueryTask")](ID: \(id.debugDescription))"
  }
}

extension QueryTask {
  /// This task's info.
  public var info: QueryTaskInfo {
    QueryTaskInfo(id: self.id, configuration: self.configuration)
  }
}

extension QueryContext {
  /// The ``QueryTaskInfo`` of the currently running ``QueryTask`` in this context.
  ///
  /// This value is non-nil when accessed from a context within ``QueryRequest/fetch(in:with:)``.
  public var queryRunningTaskInfo: QueryTaskInfo? {
    get { self[QueryTaskInfoKey.self] }
    set { self[QueryTaskInfoKey.self] = newValue }
  }

  private enum QueryTaskInfoKey: Key {
    static var defaultValue: QueryTaskInfo? { nil }
  }
}
