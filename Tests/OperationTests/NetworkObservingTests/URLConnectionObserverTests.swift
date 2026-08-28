import Clocks
import CustomDump
import Foundation
import Operation
import XCTest

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

final class URLConnectionObserverTests: XCTestCase {
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testIsRunningReturnsTrueAfterInit() async throws {
    MockURLProtocol.setHandler { _ in throw SomeError() }
    let observer = URLConnectionObserver(session: Self.makeSession(), clock: TestClock())

    expectNoDifference(observer.isRunning, false)
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testIsRunningReturnsFalseAfterStop() async throws {
    MockURLProtocol.setHandler { _ in throw SomeError() }
    let observer = URLConnectionObserver.starting(session: Self.makeSession(), clock: TestClock())

    observer.stop()

    expectNoDifference(observer.isRunning, false)
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testStartingFactoryCreatesRunningObserver() async throws {
    MockURLProtocol.setHandler { _ in throw SomeError() }
    let observer = URLConnectionObserver.starting(
      session: Self.makeSession(),
      clock: TestClock(),
      pingingEvery: .seconds(1)
    )

    expectNoDifference(observer.isRunning, true)
    observer.stop()
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testStartingSharedWorksCorrectly() async throws {
    MockURLProtocol.setHandler { _ in throw SomeError() }

    let observer = URLConnectionObserver.startingShared()

    expectNoDifference(observer.isRunning, true)
    observer.stop()
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testInitialFailedPingBecomesDisconnected() async throws {
    MockURLProtocol.setHandler { _ in throw URLError(.notConnectedToInternet) }
    let observer = URLConnectionObserver(session: Self.makeSession(), clock: TestClock())
    defer { observer.stop() }

    let status = try await self.waitForStatus(from: observer, where: { $0 == .disconnected })

    expectNoDifference(status, .disconnected)
    expectNoDifference(observer.currentStatus, .disconnected)
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testLaterSuccessfulPingBecomesConnected() async throws {
    let attempts = Counter()
    let clock = TestClock()
    MockURLProtocol.setHandler { request in
      if attempts.increment() < 2 {
        throw URLError(.networkConnectionLost)
      }
      return (Self.makeResponse(for: request.url!), Data())
    }

    let observer = URLConnectionObserver(
      session: Self.makeSession(),
      clock: clock,
      pingingEvery: .seconds(1)
    )
    defer { observer.stop() }

    let disconnected = try await self.waitForStatus(from: observer, where: { $0 == .disconnected })
    expectNoDifference(disconnected, .disconnected)

    await clock.advance(by: .zero)
    await clock.advance(by: .seconds(1))

    let connected = try await self.waitForStatus(from: observer, where: { $0 == .connected })
    expectNoDifference(connected, .connected)
    expectNoDifference(observer.currentStatus, .connected)
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testConnectedToDisconnectedToConnected() async throws {
    let attempts = Counter()
    let clock = TestClock()
    let initialPingStarted = self.expectation(description: "Initial ping started")
    MockURLProtocol.setHandler { request in
      let attempt = attempts.increment()
      if attempt % 2 == 1 {
        return (Self.makeResponse(for: request.url!), Data())
      }
      throw URLError(.timedOut)
    }
    MockURLProtocol.startupExpectation = initialPingStarted

    let observer = URLConnectionObserver.starting(
      session: Self.makeSession(),
      clock: clock,
      pingingEvery: .seconds(1)
    )
    defer { observer.stop() }

    let statuses = StatusBox()
    let subscription = observer.subscribe { status in
      statuses.append(status)
    }
    defer { subscription.cancel() }

    await self.fulfillment(of: [initialPingStarted], timeout: 1)

    let connected = try await self.waitForStatus(from: observer, where: { $0 == .connected })
    expectNoDifference(connected, .connected)

    await clock.advance(by: .zero)
    await clock.advance(by: .seconds(1))
    let disconnected = try await self.waitForStatus(from: observer, where: { $0 == .disconnected })
    expectNoDifference(disconnected, .disconnected)

    await clock.advance(by: .zero)
    await clock.advance(by: .seconds(1))
    let connectedAgain = try await self.waitForStatus(from: observer, where: { $0 == .connected })
    expectNoDifference(connectedAgain, .connected)

    expectNoDifference(statuses.values.suffix(3), [.connected, .disconnected, .connected])
    expectNoDifference(observer.currentStatus, .connected)
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testDisconnectedToConnectedToDisconnected() async throws {
    let attempts = Counter()
    let clock = TestClock()
    let initialPingStarted = self.expectation(description: "Initial ping started")
    MockURLProtocol.setHandler { request in
      let attempt = attempts.increment()
      if attempt % 2 == 0 {
        return (Self.makeResponse(for: request.url!), Data())
      }
      throw URLError(.dataNotAllowed)
    }
    MockURLProtocol.startupExpectation = initialPingStarted

    let observer = URLConnectionObserver.starting(
      session: Self.makeSession(),
      clock: clock,
      pingingEvery: .seconds(1)
    )
    defer { observer.stop() }

    let statuses = StatusBox()
    let subscription = observer.subscribe { status in
      statuses.append(status)
    }
    defer { subscription.cancel() }

    await self.fulfillment(of: [initialPingStarted], timeout: 1)

    let disconnected = try await self.waitForStatus(from: observer, where: { $0 == .disconnected })
    expectNoDifference(disconnected, .disconnected)

    await clock.advance(by: .zero)
    await clock.advance(by: .seconds(1))
    let connected = try await self.waitForStatus(from: observer, where: { $0 == .connected })
    expectNoDifference(connected, .connected)

    await clock.advance(by: .zero)
    await clock.advance(by: .seconds(1))
    let disconnectedAgain = try await self.waitForStatus(
      from: observer,
      where: { $0 == .disconnected }
    )
    expectNoDifference(disconnectedAgain, .disconnected)

    expectNoDifference(statuses.values.suffix(3), [.disconnected, .connected, .disconnected])
    expectNoDifference(observer.currentStatus, .disconnected)
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testDuplicateStatusesDoNotNotifySubscribers() async throws {
    let clock = TestClock()
    let initialPingStarted = self.expectation(description: "Initial ping started")
    MockURLProtocol.setHandler { request in
      (Self.makeResponse(for: request.url!), Data())
    }
    MockURLProtocol.startupExpectation = initialPingStarted

    let observer = URLConnectionObserver.starting(
      session: Self.makeSession(),
      clock: clock,
      pingingEvery: .seconds(1)
    )
    defer { observer.stop() }
    let statuses = StatusBox()
    let subscription = observer.subscribe { status in
      statuses.append(status)
    }
    defer { subscription.cancel() }

    await self.fulfillment(of: [initialPingStarted], timeout: 1)
    await clock.advance(by: .zero)
    await clock.advance(by: .seconds(1))

    expectNoDifference(statuses.values, [.connected])
    expectNoDifference(observer.currentStatus, .connected)
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testNonConnectionErrorsStayConnected() async throws {
    let clock = TestClock()
    MockURLProtocol.setHandler { _ in throw SomeError() }

    let observer = URLConnectionObserver(
      session: Self.makeSession(),
      clock: clock,
      pingingEvery: .seconds(1)
    )
    defer { observer.stop() }
    let statuses = StatusBox()
    let subscription = observer.subscribe { status in
      statuses.append(status)
    }
    defer { subscription.cancel() }

    await clock.advance(by: .zero)
    await clock.advance(by: .seconds(1))

    expectNoDifference(statuses.values, [.connected])
    expectNoDifference(observer.currentStatus, .connected)
  }

  private struct SomeError: Error {}

  private func waitForStatus(
    from observer: URLConnectionObserver,
    where predicate: @escaping @Sendable (NetworkConnectionStatus) -> Bool
  ) async throws -> NetworkConnectionStatus {
    let statusBox = Lock<NetworkConnectionStatus?>(nil)
    let expectation = self.expectation(description: "Produces matching connection status")
    let subscription = observer.subscribe { status in
      guard predicate(status) else { return }
      let shouldFulfill = statusBox.withLock { storedStatus in
        guard storedStatus == nil else { return false }
        storedStatus = status
        return true
      }
      if shouldFulfill {
        expectation.fulfill()
      }
    }
    defer { subscription.cancel() }

    await self.fulfillment(of: [expectation], timeout: 1)
    return try XCTUnwrap(statusBox.withLock { $0 })
  }

  private static func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  private static func makeResponse(for url: URL) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
  }
}

private final class Counter: Sendable {
  private let lock = Lock(0)

  func increment() -> Int {
    self.lock.withLock {
      $0 += 1
      return $0
    }
  }
}

private final class StatusBox: Sendable {
  private let statuses = Lock([NetworkConnectionStatus]())

  var values: [NetworkConnectionStatus] {
    self.statuses.withLock { $0 }
  }

  func append(_ status: NetworkConnectionStatus) {
    self.statuses.withLock { $0.append(status) }
  }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
  private struct State: Sendable {
    var startupExpectation: XCTestExpectation?
    var handler: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data) = { _ in
      fatalError("Unhandled request.")
    }
  }

  private static let state = Lock(State())

  static var startupExpectation: XCTestExpectation? {
    get { Self.state.withLock { $0.startupExpectation } }
    set { Self.state.withLock { $0.startupExpectation = newValue } }
  }

  static func setHandler(
    _ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
  ) {
    Self.state.withLock {
      $0.startupExpectation = nil
      $0.handler = handler
    }
  }

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    let (startupExpectation, handler) = Self.state.withLock { state in
      let startupExpectation = state.startupExpectation
      state.startupExpectation = nil
      return (startupExpectation, state.handler)
    }
    startupExpectation?.fulfill()
    do {
      let (response, data) = try handler(self.request)
      self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      self.client?.urlProtocol(self, didLoad: data)
      self.client?.urlProtocolDidFinishLoading(self)
    } catch {
      self.client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
