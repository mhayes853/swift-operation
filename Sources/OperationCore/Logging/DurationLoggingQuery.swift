#if SwiftOperationLogging
  import Logging
  import Foundation

  extension QueryRequest {
    /// Logs the runtime duration of each fetch for this query in seconds.
    ///
    /// - Parameters:
    ///   - logger: A `Logger` to use (defaults to the logger in ``OperationContext``.
    ///   - level: The level to log the duration message at.
    /// - Returns: A ``ModifiedQuery``.
    public func logDuration(
      with logger: Logger? = nil,
      at level: Logger.Level = .info
    ) -> ModifiedQuery<Self, _DurationLoggingModifier<Self>> {
      self.modifier(_DurationLoggingModifier(logger: logger, level: level))
    }
  }

  public struct _DurationLoggingModifier<Query: QueryRequest>: QueryModifier {
    let logger: Logger?
    let level: Logger.Level

    public func fetch(
      in context: OperationContext,
      using query: Query,
      with continuation: OperationContinuation<Query.Value>
    ) async throws -> Query.Value {
      let logger = self.logger ?? context.operationLogger
      let start = context.operationClock.now()
      defer {
        let end = context.operationClock.now()
        let duration = end.timeIntervalSince1970 - start.timeIntervalSince1970
        logger.log(
          level: self.level,
          "An operation finished running.",
          metadata: [
            "operation.type": "\(query._debugTypeName)",
            "operation.duration": "\(duration.durationFormatted())"
          ]
        )
      }
      return try await query.fetch(in: context, with: continuation)
    }
  }
#endif
