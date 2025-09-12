import ConcurrencyExtras
import FoundationModels
import Logging

extension Tool {
  public func withLogging() -> some Tool<Arguments, Output> {
    LoggingTool(base: self)
  }
}

private struct LoggingTool<Base: Tool>: Tool {
  let base: Base

  var name: String { self.base.name }
  var description: String { self.base.description }
  var includesSchemaInInstructions: Bool { self.base.includesSchemaInInstructions }
  var parameters: GenerationSchema { self.base.parameters }

  func call(arguments: Base.Arguments) async throws -> Base.Output {
    var result: Result<Base.Output, any Error>?
    let clock = ContinuousClock()
    let time = await clock.measure {
      result = await Result { try await self.base.call(arguments: arguments) }
    }
    currentLogger.debug(
      "'\(self.name)' tool called.",
      metadata: [
        "call.arguments": "\(arguments)",
        "call.result": "\(result!)",
        "call.duration": "\(time)"
      ]
    )
    return try result!.get()
  }
}
