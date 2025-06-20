import JavaScriptEventLoop
import JavaScriptKit
import WASMDemoCore

@main
@MainActor
struct WASMDemo {
  static func main() {
    JavaScriptEventLoop.installGlobalExecutor()
    
    let model = AppModel()
    let container = document.getElementById!("app")
    renderApp(model: model, in: container.object!)
  }
}