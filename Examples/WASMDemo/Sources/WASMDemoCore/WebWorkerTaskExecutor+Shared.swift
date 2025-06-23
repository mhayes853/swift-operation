import JavaScriptEventLoop
import JavaScriptKit
import Dependencies

// MARK: - SharedInstance

extension WebWorkerTaskExecutor {
  @MainActor
  public static func sharedInstance() async throws -> WebWorkerTaskExecutor {
    let concurrency = Int(window.navigator.hardwareConcurrency.number!)
    return try await WebWorkerTaskExecutor(numberOfThreads: concurrency)
  }
}

// MARK: - DependencyKey

public enum WebWorkerTaskExecutorKey: DependencyKey {
  public static let liveValue: (any TaskExecutor)? = nil
}