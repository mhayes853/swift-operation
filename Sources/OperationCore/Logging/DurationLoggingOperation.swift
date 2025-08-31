#if SwiftOperationLogging
  import Logging
  import Foundation

  extension OperationRequest {
    /// Logs the runtime duration of each fetch for this query in seconds.
    ///
    /// - Parameters:
    ///   - logger: A `Logger` to use (defaults to the logger in ``OperationContext``.
    ///   - level: The level to log the duration message at.
    /// - Returns: A ``ModifiedOperation``.
    public func logDuration(
      with logger: Logger? = nil,
      at level: Logger.Level = .info
    ) -> ModifiedOperation<Self, _DurationLoggingModifier<Self>> {
      self.modifier(_DurationLoggingModifier(logger: logger, level: level))
    }
  }

  public struct _DurationLoggingModifier<Operation: OperationRequest>: OperationModifier, Sendable {
    let logger: Logger?
    let level: Logger.Level

    public func run(
      isolation: isolated (any Actor)?,
      in context: OperationContext,
      using operation: Operation,
      with continuation: OperationContinuation<Operation.Value, Operation.Failure>
    ) async throws -> Operation.Value {
      let logger = self.logger ?? context.operationLogger
      let start = context.operationClock.now()
      defer {
        let end = context.operationClock.now()
        let duration = end.timeIntervalSince1970 - start.timeIntervalSince1970
        logger.log(
          level: self.level,
          "An operation finished running.",
          metadata: [
            "operation.type": "\(operation._debugTypeName)",
            "operation.duration": "\(duration.durationFormatted())"
          ]
        )
      }
      return try await operation.run(isolation: isolation, in: context, with: continuation)
    }
  }
#endif
