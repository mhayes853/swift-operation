import Dependencies
import JavaScriptEventLoop
import JavaScriptKit

// MARK: - SharedInstance

extension WebWorkerTaskExecutor {
  @MainActor
  public static func sharedInstance(
    timeout: Duration = .seconds(30)
  ) async throws -> WebWorkerTaskExecutor {
    let concurrency = Int(window.navigator.hardwareConcurrency.number!)
    return try await WebWorkerTaskExecutor(numberOfThreads: concurrency, timeout: timeout)
  }
}

// MARK: - DependencyKey

public enum WebWorkerTaskExecutorKey: DependencyKey {
  public static let liveValue: (any TaskExecutor)? = nil
}
