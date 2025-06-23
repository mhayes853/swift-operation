import JavaScriptEventLoop
import JavaScriptKit
import WASMDemoCore
import Dependencies

@main
struct WASMDemo {
  static func main() async throws {
    JavaScriptEventLoop.installGlobalExecutor()

    // TODO: - The act of initializing the executor seems to break observation and/or the ability
    // to schedule unstructured tasks.
    // #if canImport(wasi_pthread) && _runtime(_multithreaded)
    //   let executor = try await WebWorkerTaskExecutor.sharedInstance()
    //   prepareDependencies { 
    //     $0[WebWorkerTaskExecutorKey.self] = executor
    //   }
    // #endif

    let model = AppModel()
    let container = document.getElementById!("app")
    renderApp(model: model, in: container.object!)
  }
}