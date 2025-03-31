#if canImport(Dispatch)
  import Foundation

  extension MainActor {
    /// A backport of `MainActor.assumeIsolated`.
    @_unavailableFromAsync(message:"await the call to the @MainActor closure directly")
    static func runAssumingIsolation<T: Sendable>(
      _ operation: @MainActor () throws -> T,
      file: StaticString = #fileID,
      line: UInt = #line
    ) rethrows -> T {
      #if swift(<5.10)
        guard Thread.isMainThread else {
          fatalError(
            "Incorrect actor executor assumption; Expected same executor as \(self).",
            file: file,
            line: line
          )
        }
        // NB: To do the unsafe cast, we have to pretend it's @escaping.
        return try withoutActuallyEscaping(operation) {
          try unsafeBitCast($0, to: (() throws -> T).self)()
        }
      #else
        return try assumeIsolated(operation, file: file, line: line)
      #endif
    }
  }

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
        try Self.runAssumingIsolation(operation, file: file, line: line)
      } else {
        try DispatchQueue.main.sync { try operation() }
      }
    }
  }
#endif