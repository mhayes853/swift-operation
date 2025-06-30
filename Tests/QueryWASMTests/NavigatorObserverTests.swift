#if os(WASI)
  import JavaScriptKit
  import QueryBrowser
  import QueryCore
  import XCTest

  final class NavigatorObserverTests: XCTestCase {
    private let navigator = JSObject()
    private let observer = NavigatorObserver(navigatorProperty: "fakeNavigator")

    override func setUp() {
      super.setUp()
      window.fakeNavigator = .object(self.navigator)
    }

    func testConnectedWhenOnlineTrue() {
      self.navigator.onLine = .boolean(true)
      XCTAssertEqual(self.observer.currentStatus, NetworkConnectionStatus.connected)
    }

    func testDisconnectedWhenOnlineFalse() {
      self.navigator.onLine = .boolean(false)
      XCTAssertEqual(self.observer.currentStatus, NetworkConnectionStatus.disconnected)
    }

    func testObservesOnlineChanges() {
      self.navigator.onLine = .boolean(true)

      let values = Lock([NetworkConnectionStatus]())
      let subscription = self.observer.subscribe { status in
        values.withLock { $0.append(status) }
      }

      let onlineEvent = JSObject.global.Event.function!.new("online")
      let offlineEvent = JSObject.global.Event.function!.new("offline")
      window.dispatchEvent!(offlineEvent)
      window.dispatchEvent!(onlineEvent)
      window.dispatchEvent!(offlineEvent)

      values.withLock {
        XCTAssertEqual(
          $0,
          [NetworkConnectionStatus.connected, .disconnected, .connected, .disconnected]
        )
      }

      subscription.cancel()
    }
  }
#endif
