import ConcurrencyExtras
import FoundationModels
import Logging

extension Tool where Arguments: Sendable {
  public func withLogging() -> some Tool<Arguments, Output> {
    LoggingTool(base: self)
  }
}

private struct LoggingTool<Base: Tool>: Tool where Base.Arguments: Sendable {
  let base: Base

  var name: String { self.base.name }
  var description: String { self.base.description }
  var includesSchemaInInstructions: Bool { self.base.includesSchemaInInstructions }
  var parameters: GenerationSchema { self.base.parameters }

  func call(arguments: Base.Arguments) async throws -> Base.Output {
    let clock = ContinuousClock()
    let start = clock.now
    let argumentsDescription = "\(arguments)"
    let result = await Result { try await self.base.call(arguments: arguments) }
    currentLogger.debug(
      "'\(self.name)' tool called.",
      metadata: [
        "call.arguments": "\(argumentsDescription)",
        "call.result": "\(result)",
        "call.duration": "\(start.duration(to: clock.now))"
      ]
    )
    return try result.get()
  }
}
