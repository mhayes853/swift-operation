#if canImport(JavaScriptKit)
  import JavaScriptKit
  import QueryBrowser
  import QueryCore
  import XCTest

  final class WindowIsVisibleConditionTests: XCTestCase {
    func testIsSatisfiedWhenVisibilityStateIsVisible() {
      let document = JSObject()
      document.visibilityState = .string("visible")

      let condition: some FetchCondition = .windowIsVisible(document: document, window: window)
      XCTAssertTrue(condition.isSatisfied(in: QueryContext()))
    }

    func testIsNotSatisfiedWhenVisibilityStateIsHidden() {
      let document = JSObject()
      document.visibilityState = .string("hidden")

      let condition: some FetchCondition = .windowIsVisible(document: document, window: window)
      XCTAssertFalse(condition.isSatisfied(in: QueryContext()))
    }

    func testNeverSatisfiedWhenFocusRefetchingDisabled() {
      var context = QueryContext()
      context.isFocusRefetchingEnabled = false

      let document = JSObject()
      document.visibilityState = .string("visible")

      let condition: some FetchCondition = .windowIsVisible(document: document, window: window)
      XCTAssertFalse(condition.isSatisfied(in: context))

      document.visibilityState = .string("hidden")
      XCTAssertFalse(condition.isSatisfied(in: context))
    }

    func testEmitsFalseWithEmptySubscripitionWhenFocusFetchingDisabled() {
      let document = JSObject()
      document.visibilityState = .string("visible")

      let condition: some FetchCondition = .windowIsVisible(document: document, window: window)

      let satisfactions = Lock([Bool]())
      var context = QueryContext()
      context.isFocusRefetchingEnabled = false
      let subscription = condition.subscribe(in: context) { value in
        satisfactions.withLock { $0.append(value) }
      }
      XCTAssertEqual(subscription, .empty)
      satisfactions.withLock { XCTAssertEqual($0, [false]) }
      subscription.cancel()
    }

    func testSubscribesToVisibilityStateChanges() {
      let document = JSObject()
      document.visibilityState = .string("visible")

      let condition: some FetchCondition = .windowIsVisible(document: document, window: window)
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
