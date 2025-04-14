#if canImport(JavaScriptKit)
  import JavaScriptKit
  import QueryBrowser
  import QueryCore
  import XCTest

  final class NavigatorObserverTests: XCTestCase {
    func testConnectedWhenOnlineTrue() {
      let navigator = JSObject()
      navigator.onLine = .boolean(true)
      let observer = NavigatorObserver(navigator: navigator, window: window)

      XCTAssertEqual(observer.currentStatus, NetworkStatus.connected)
    }

    func testDisconnectedWhenOnlineFalse() {
      let navigator = JSObject()
      navigator.onLine = .boolean(false)
      let observer = NavigatorObserver(navigator: navigator, window: window)

      XCTAssertEqual(observer.currentStatus, NetworkStatus.disconnected)
    }

    func testObservesOnlineChanges() {
      let navigator = JSObject()
      navigator.onLine = .boolean(true)
      let observer = NavigatorObserver(navigator: navigator, window: window)

      let values = Lock([NetworkStatus]())
      let subscription = observer.subscribe { status in
        values.withLock { $0.append(status) }
      }

      let onlineEvent = JSObject.global.Event.function!.new("online")
      let offlineEvent = JSObject.global.Event.function!.new("offline")
      window.dispatchEvent!(offlineEvent)
      window.dispatchEvent!(onlineEvent)
      window.dispatchEvent!(offlineEvent)

      values.withLock {
        XCTAssertEqual($0, [NetworkStatus.connected, .disconnected, .connected, .disconnected])
      }

      subscription.cancel()
    }
  }
#endif
