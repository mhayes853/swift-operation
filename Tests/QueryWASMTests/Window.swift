#if os(WASI)
  import JavaScriptKit

  nonisolated(unsafe) let window = JSObject.global.window.object!
#endif
