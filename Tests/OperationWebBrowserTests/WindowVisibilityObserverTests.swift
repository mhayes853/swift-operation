#if os(WASI)
  import JavaScriptKit
  import OperationWebBrowser
  import OperationCore
  import XCTest

  final class WindowVisibilityObserverTests: XCTestCase {
    func testIsSatisfiedWhenVisibilityStateIsVisible() {
      let window = TestWindow(visibility: .visible)

      let condition: some FetchCondition = .applicationIsActive(observer: window.observer)
      XCTAssertTrue(condition.isSatisfied(in: QueryContext()))
    }

    func testIsNotSatisfiedWhenVisibilityStateIsHidden() {
      let window = TestWindow(visibility: .hidden)

      let condition: some FetchCondition = .applicationIsActive(observer: window.observer)
      XCTAssertFalse(condition.isSatisfied(in: QueryContext()))
    }

    func testSubscribesToVisibilityStateChanges() {
      let window = TestWindow(visibility: .visible)

      let condition: some FetchCondition = .applicationIsActive(observer: window.observer)

      let values = Lock([Bool]())
      let subscription = condition.subscribe(in: QueryContext()) { value in
        values.withLock { $0.append(value) }
      }

      window.change(visibility: .hidden)
      window.change(visibility: .visible)

      values.withLock { XCTAssertEqual($0, [true, false, true]) }

      subscription.cancel()
    }
  }

  private enum WindowVisbility: String, Sendable {
    case visible
    case hidden
  }

  private final class TestWindow: @unchecked Sendable {
    private let document: JSObject

    var observer: WindowVisibilityObserver {
      WindowVisibilityObserver(documentProperty: "fakeDocument")
    }

    init(visibility: WindowVisbility) {
      let document = JSObject()
      document.visibilityState = .string(visibility.rawValue)
      window.fakeDocument = .object(document)
      self.document = document
    }

    func change(visibility: WindowVisbility) {
      let event = JSObject.global.Event.function!.new("visibilitychange")
      self.document.visibilityState = .string(visibility.rawValue)
      window.dispatchEvent!(event)
    }
  }
#endif
