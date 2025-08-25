#if SwiftOperationLogging
  import Logging

  extension QueryContext {
    /// A `Logger` instance used for logging query-related events.
    public var queryLogger: Logger {
      get { self[QueryLoggerKey.self] }
      set { self[QueryLoggerKey.self] = newValue }
    }

    private enum QueryLoggerKey: Key {
      static let defaultValue = Logger(label: "swift.query")
    }
  }
#endif
