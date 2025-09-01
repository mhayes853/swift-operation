#if SwiftOperationLogging
  import CustomDump
  import Operation
  import OperationTestHelpers
  import Testing
  import Logging
  import Foundation

  @Suite("DurationLoggingOperation tests")
  struct DurationLoggingOperationTests {
    @Test("Logs Duration To Query")
    func logsDurationToQuery() async throws {
      let handler = TestHandler()
      let logger = Logger(label: "test.query") { _ in handler }
      let clock = IncrementingClock()
      let store = OperationStore.detached(
        query: TestQuery().disableApplicationActiveRefetching()
          .logDuration(with: logger, at: .debug),
        initialValue: nil
      )
      store.context.operationClock = clock

      try await store.fetch()

      handler.messages.inner.withLock { messages in
        expectNoDifference(
          messages,
          [
            TestHandler.Message(
              message: "An operation finished running.",
              level: .debug,
              metadata: ["operation.type": "TestQuery", "operation.duration": "1.0 sec"]
            )
          ]
        )
      }
    }
  }

  private struct TestHandler: LogHandler {
    struct Message: Equatable, Sendable {
      let message: Logger.Message
      let level: Logger.Level
      let metadata: Logger.Metadata
    }

    let messages = LockedBox(value: [Message]())

    var metadata = Logger.Metadata()
    var logLevel = Logger.Level.debug

    subscript(metadataKey key: String) -> Logger.MetadataValue? {
      get { self.metadata[key] }
      set { self.metadata[key] = newValue }
    }

    func log(
      level: Logger.Level,
      message: Logger.Message,
      metadata: Logger.Metadata?,
      source: String,
      file: String,
      function: String,
      line: UInt
    ) {
      self.messages.inner.withLock {
        $0.append(Message(message: message, level: level, metadata: metadata ?? [:]))
      }
    }
  }
#endif
