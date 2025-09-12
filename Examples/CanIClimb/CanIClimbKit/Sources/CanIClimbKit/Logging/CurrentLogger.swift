import Logging

public var currentLogger: Logger {
  LoggerLocal.current
}

public func withCurrentLogger<T>(
  _ logger: Logger,
  operation: () async throws -> T
) async rethrows -> T {
  try await LoggerLocal.$current.withValue(logger, operation: operation)
}

public func withCurrentLogger<T>(
  _ logger: Logger,
  operation: () throws -> T
) rethrows -> T {
  try LoggerLocal.$current.withValue(logger, operation: operation)
}

private enum LoggerLocal {
  @TaskLocal static var current = Logger(label: "caniclimb")
}
