#if canImport(JavaScriptKit)
  import JavaScriptKit
  import QueryCore
  import XCTest

  final class WindowFocusConditionTests: XCTestCase {
    func testIsSatisfiedWhenVisibilityStateIsVisible() {
      let document = JSObject()
      document.visibilityState = .string("visible")

      let condition: some FetchCondition = .windowFocus(document: document, window: window)
      XCTAssertTrue(condition.isSatisfied(in: QueryContext()))
    }

    func testIsNotSatisfiedWhenVisibilityStateIsHidden() {
      let document = JSObject()
      document.visibilityState = .string("hidden")

      let condition: some FetchCondition = .windowFocus(document: document, window: window)
      XCTAssertFalse(condition.isSatisfied(in: QueryContext()))
    }

    func testSubscribesToVisibilityStateChanges() {
      let document = JSObject()
      document.visibilityState = .string("visible")

      let condition: some FetchCondition = .windowFocus(document: document, window: window)
      let values = Lock([Bool]())
      let subscription = condition.subscribe(in: QueryContext()) { value in
        values.withLock { $0.append(value) }
      }

      let event = JSObject.global.Event.function!.new("visibilitychange")
      document.visibilityState = .string("hidden")
      window.dispatchEvent!(event)
      document.visibilityState = .string("visible")
      window.dispatchEvent!(event)

      values.withLock { XCTAssertEqual($0, [true, false, true]) }

      subscription.cancel()
    }
  }
#endif
