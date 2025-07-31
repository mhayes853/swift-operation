import Dependencies
import JavaScriptEventLoop
import JavaScriptKit
import WASMDemoCore

@main
struct WASMDemo {
  static func main() async throws {
    JavaScriptEventLoop.installGlobalExecutor()

    #if canImport(wasi_pthread) && _runtime(_multithreaded)
      let executor = try await WebWorkerTaskExecutor.sharedInstance()
      prepareDependencies {
        $0[WebWorkerTaskExecutorKey.self] = executor
      }
    #endif

    let model = AppModel()
    let container = document.getElementById!("app")
    renderApp(model: model, in: container.object!)

    // NB: This is needed when running with WebWorkerTaskExecutor to prevent the program from
    // exiting. Otherwise, the UI becomes unresponsive.
    try await Task.never()
  }
}

#if canImport(wasi_pthread)
  import wasi_pthread
  import WASILibc

  /// Trick to avoid blocking the main thread. pthread_mutex_lock function is used by
  /// the Swift concurrency runtime.
  @_cdecl("pthread_mutex_lock")
  func pthread_mutex_lock(_ mutex: UnsafeMutablePointer<pthread_mutex_t>) -> Int32 {
    // DO NOT BLOCK MAIN THREAD
    var ret: Int32
    repeat {
      ret = pthread_mutex_trylock(mutex)
    } while ret == EBUSY
    return ret
  }
#endif
