#if SwiftLog
  import Logging

  extension QueryContext {
    public var queryLogger: Logger {
      get { self[QueryLoggerKey.self] }
      set { self[QueryLoggerKey.self] = newValue }
    }

    private enum QueryLoggerKey: Key {
      static let defaultValue = Logger(label: "swift.query")
    }
  }
#endif
