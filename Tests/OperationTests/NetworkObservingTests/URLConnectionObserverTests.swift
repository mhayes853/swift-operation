import Clocks
import CustomDump
import Foundation
import Operation
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite("URLConnectionObserver tests", .serialized)
struct URLConnectionObserverTests {
  @Test("Is Running Returns True After Init")
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func isRunningReturnsTrueAfterInit() async throws {
    MockURLProtocol.setHandler { _ in throw SomeError() }
    let observer = URLConnectionObserver(session: Self.makeSession(), clock: TestClock())

    expectNoDifference(observer.isRunning, false)
  }

  @Test("Is Running Returns False After Stop")
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func isRunningReturnsFalseAfterStop() async throws {
    MockURLProtocol.setHandler { _ in throw SomeError() }
    let observer = URLConnectionObserver.starting(session: Self.makeSession(), clock: TestClock())

    observer.stop()

    expectNoDifference(observer.isRunning, false)
  }

  @Test("Starting Factory Creates Running Observer")
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func startingFactoryCreatesRunningObserver() async throws {
    MockURLProtocol.setHandler { _ in throw SomeError() }
    let observer = URLConnectionObserver.starting(
      session: Self.makeSession(),
      clock: TestClock(),
      pingingEvery: .seconds(1)
    )

    expectNoDifference(observer.isRunning, true)
    observer.stop()
  }

  @Test("Starting Shared Works Correctly")
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func startingSharedWorksCorrectly() async throws {
    MockURLProtocol.setHandler { _ in throw SomeError() }

    let observer = URLConnectionObserver.startingShared()

    expectNoDifference(observer.isRunning, true)
  }

  @Test("Initial Failed Ping Becomes Disconnected")
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func initialFailedPingBecomesDisconnected() async throws {
    MockURLProtocol.setHandler { _ in throw SomeError() }
    let observer = URLConnectionObserver(session: Self.makeSession(), clock: TestClock())

    let status = try await self.nextStatus(from: observer, where: { $0 == .disconnected })

    expectNoDifference(status, .disconnected)
    expectNoDifference(observer.currentStatus, .disconnected)
  }

  @Test("Later Successful Ping Becomes Connected")
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func laterSuccessfulPingBecomesConnected() async throws {
    let attempts = Counter()
    let clock = TestClock()
    MockURLProtocol.setHandler { request in
      if attempts.increment() < 2 {
        throw SomeError()
      }
      return (Self.makeResponse(for: request.url!), Data())
    }

    let observer = URLConnectionObserver(
      session: Self.makeSession(),
      clock: clock,
      pingingEvery: .seconds(1)
    )

    let disconnected = try await self.nextStatus(from: observer, where: { $0 == .disconnected })
    expectNoDifference(disconnected, .disconnected)

    await clock.advance(by: .zero)
    await clock.advance(by: .seconds(1))

    let connected = try await self.nextStatus(from: observer, where: { $0 == .connected })
    expectNoDifference(connected, .connected)
    expectNoDifference(observer.currentStatus, .connected)
  }

  @Test("Connected -> Disconnected -> Connected")
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func connectedToDisconnectedToConnected() async throws {
    let attempts = Counter()
    let clock = TestClock()
    MockURLProtocol.setHandler { request in
      let attempt = attempts.increment()
      if attempt % 2 == 1 {
        return (Self.makeResponse(for: request.url!), Data())
      }
      throw SomeError()
    }

    let observer = URLConnectionObserver(
      session: Self.makeSession(),
      clock: clock,
      pingingEvery: .seconds(1)
    )

    let connected = try await self.nextStatus(from: observer, where: { $0 == .connected })
    expectNoDifference(connected, .connected)

    await clock.advance(by: .seconds(1))

    let disconnected = try await self.nextStatus(from: observer, where: { $0 == .disconnected })
    expectNoDifference(disconnected, .disconnected)

    await clock.advance(by: .seconds(1))

    let connectedAgain = try await self.nextStatus(from: observer, where: { $0 == .connected })
    expectNoDifference(connectedAgain, .connected)
    expectNoDifference(observer.currentStatus, .connected)
  }

  @Test("Disconnected -> Connected -> Disconnected")
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func disconnectedToConnectedToDisconnected() async throws {
    let attempts = Counter()
    let clock = TestClock()
    MockURLProtocol.setHandler { request in
      let attempt = attempts.increment()
      if attempt % 2 == 0 {
        return (Self.makeResponse(for: request.url!), Data())
      }
      throw SomeError()
    }

    let observer = URLConnectionObserver(
      session: Self.makeSession(),
      clock: clock,
      pingingEvery: .seconds(1)
    )

    let disconnected = try await self.nextStatus(from: observer, where: { $0 == .disconnected })
    expectNoDifference(disconnected, .disconnected)

    await clock.advance(by: .seconds(1))

    let connected = try await self.nextStatus(from: observer, where: { $0 == .connected })
    expectNoDifference(connected, .connected)

    await clock.advance(by: .seconds(1))

    let disconnectedAgain = try await self.nextStatus(
      from: observer,
      where: { $0 == .disconnected }
    )
    expectNoDifference(disconnectedAgain, .disconnected)
    expectNoDifference(observer.currentStatus, .disconnected)
  }

  @Test("Duplicate Statuses Do Not Notify Subscribers")
  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func duplicateStatusesDoNotNotifySubscribers() async throws {
    let clock = TestClock()
    MockURLProtocol.setHandler { request in
      (Self.makeResponse(for: request.url!), Data())
    }

    let observer = URLConnectionObserver(
      session: Self.makeSession(),
      clock: clock,
      pingingEvery: .seconds(1)
    )
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

  private func nextStatus(
    from observer: URLConnectionObserver,
    where predicate: @escaping @Sendable (NetworkConnectionStatus) -> Bool
  ) async throws -> NetworkConnectionStatus {
    try await withThrowingTaskGroup(of: NetworkConnectionStatus.self) { group in
      group.addTask {
        let stream = AsyncThrowingStream<NetworkConnectionStatus, any Error> { continuation in
          let subscription = observer.subscribe { status in
            continuation.yield(status)
          }
          continuation.onTermination = { _ in
            subscription.cancel()
          }
        }

        for try await status in stream {
          if predicate(status) {
            return status
          }
        }

        throw SomeError()
      }

      group.addTask {
        try await Task.sleep(for: .seconds(1))
        throw SomeError()
      }

      let status = try await group.next()!
      group.cancelAll()
      return status
    }
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
  nonisolated(unsafe) private static var handler:
    @Sendable (URLRequest) throws -> (
      HTTPURLResponse,
      Data
    ) = { _ in
      fatalError("Unhandled request.")
    }

  static func setHandler(
    _ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
  ) {
    Self.handler = handler
  }

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    do {
      let (response, data) = try Self.handler(self.request)
      self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      self.client?.urlProtocol(self, didLoad: data)
      self.client?.urlProtocolDidFinishLoading(self)
    } catch {
      self.client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
