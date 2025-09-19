// MARK: - OperationTaskInfo

/// Info about an existing ``OperationTask``.
///
/// You cannot directly create instances of this type. You must get an instance from an existing
/// ``OperationTask``, or you can access the info of a running task from within an operation run.
public struct OperationTaskInfo: Sendable, Identifiable {
  public let id: OperationTaskIdentifier

  /// The ``OperationTaskConfiguration`` of the task.
  public let configuration: OperationTaskConfiguration
}

extension OperationTaskInfo: CustomStringConvertible {
  public var description: String {
    "[\(self.configuration.name ?? "Unnamed OperationTask")](ID: \(self.id.debugDescription))"
  }
}

// MARK: - OperationTask

extension OperationTask {
  /// This task's info.
  public var info: OperationTaskInfo {
    OperationTaskInfo(id: self.id, configuration: self.configuration)
  }
}
