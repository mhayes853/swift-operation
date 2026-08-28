import Dependencies
import JavaScriptEventLoop
import JavaScriptKit
import WASMDemoCore

JavaScriptEventLoop.installGlobalExecutor()

var appModel: AppModel?

#if canImport(wasi_pthread) && _runtime(_multithreaded)
  Task {
    if let executor = try? await WebWorkerTaskExecutor.sharedInstance() {
      prepareDependencies { $0[WebWorkerTaskExecutorKey.self] = executor }
    }
    startApp()
  }
#else
  startApp()
#endif

@MainActor
func startApp() {
  let model = AppModel()
  appModel = model
  let container = document.getElementById!("app")
  renderApp(model: model, in: container.object!)
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
