#if SwiftOperationLogging
  import Logging
  import Foundation

  extension QueryRequest {
    /// Logs the runtime duration of each fetch for this query in seconds.
    ///
    /// - Parameters:
    ///   - logger: A `Logger` to use (defaults to the logger in ``QueryContext``.
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
      in context: QueryContext,
      using query: Query,
      with continuation: QueryContinuation<Query.Value>
    ) async throws -> Query.Value {
      let logger = self.logger ?? context.queryLogger
      let start = context.queryClock.now()
      defer {
        let end = context.queryClock.now()
        let duration = end.timeIntervalSince1970 - start.timeIntervalSince1970
        logger.log(
          level: self.level,
          "\(query._debugTypeName) took \(duration.durationFormatted()) to run."
        )
      }
      return try await query.fetch(in: context, with: continuation)
    }
  }
#endif
