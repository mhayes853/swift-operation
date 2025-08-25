#if SwiftOperationLogging
  import Logging

  extension OperationContext {
    /// A `Logger` instance used for logging operation events.
    public var operationLogger: Logger {
      get { self[OperationLoggerKey.self] }
      set { self[OperationLoggerKey.self] = newValue }
    }

    private enum OperationLoggerKey: Key {
      static let defaultValue = Logger(label: "swift.operation")
    }
  }
#endif
