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

// MARK: - QueryTask

extension QueryTask {
  /// This task's info.
  public var info: QueryTaskInfo {
    QueryTaskInfo(id: self.id, configuration: self.configuration)
  }
}
