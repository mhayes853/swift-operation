import JavaScriptEventLoop
import JavaScriptKit
import WASMDemoCore
import Dependencies

@main
@MainActor
struct WASMDemo {
  static func main() async throws {
    JavaScriptEventLoop.installGlobalExecutor()

    #if canImport(wasi_pthreads) && _runtime(_multithreaded)
    let executor = try await WebWorkerTaskExecutor.sharedInstance()
    prepareDependencies { 
      $0[WebWorkerTaskExecutorKey.self] = executor
    }
    #endif
    
    let model = AppModel()
    let container = document.getElementById!("app")
    renderApp(model: model, in: container.object!)
  }
}