#if canImport(Dispatch)
  import Foundation

  extension MainActor {
    /// Executes the given body closure on the main actor synchronously.
    ///
    /// - Parameters:
    ///   - resultType: The return type of the operation.
    ///   - operation: The operation to run.
    /// - Returns: Whatever `operation` returns.
    static func runSync<T: Sendable>(
      resultType: T.Type = T.self,
      _ operation: @MainActor () throws -> T,
      file: StaticString = #file,
      line: UInt = #line
    ) rethrows -> T {
      if Thread.isMainThread {
        try Self.assumeIsolated(operation, file: file, line: line)
      } else {
        try DispatchQueue.main.sync { try operation() }
      }
    }
  }
#endif
