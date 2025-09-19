#if SwiftOperationLogging
  import Logging

  extension OperationContext {
    /// The current `Logger` instance in this context.
    ///
    /// The default logger has the `"swift.operation"` label applied to it.
    public var operationLogger: Logger {
      get { self[OperationLoggerKey.self] }
      set { self[OperationLoggerKey.self] = newValue }
    }

    private enum OperationLoggerKey: Key {
      static let defaultValue = Logger(label: "swift.operation")
    }
  }
#endif
