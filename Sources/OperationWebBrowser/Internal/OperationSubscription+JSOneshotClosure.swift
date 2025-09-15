#if canImport(JavaScriptKit) && canImport(JavaScriptEventLoop)
  import JavaScriptEventLoop
  import JavaScriptKit
  import OperationCore

  extension OperationSubscription {
    static func jsClosure(_ body: @escaping (sending [JSValue]) -> JSValue) -> Self {
      let closure = JSSending.transfer(JSClosure(body))
      return Self {
        Task {
          let closure = try await closure.receive() as? JSClosure
          closure?()
        }
      }
    }
  }
#endif
