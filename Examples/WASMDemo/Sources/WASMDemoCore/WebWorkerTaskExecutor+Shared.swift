import JavaScriptEventLoop
import Dependencies

// MARK: - SharedInstance

extension WebWorkerTaskExecutor {
  public static func sharedInstance() async throws -> WebWorkerTaskExecutor {
    try await WebWorkerTaskExecutor(numberOfThreads: 4)
  }
}

// MARK: - DependencyKey

public enum WebWorkerTaskExecutorKey: DependencyKey {
  public static let liveValue: WebWorkerTaskExecutor? = nil
}