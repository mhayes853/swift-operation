#if canImport(JavaScriptEventLoop)
  import JavaScriptKit
  import JavaScriptEventLoop
  import QueryCore

  extension QuerySubscription {
    static func jsOneshotClosure(_ body: @escaping (sending [JSValue]) -> JSValue) -> Self {
      let closure = JSSending.transfer(JSOneshotClosure(body))
      return Self {
        Task {
          let closure = await closure.receive()
          closure()
        }
      }
    }
  }
#endif
