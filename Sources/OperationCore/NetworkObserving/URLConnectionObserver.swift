import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - URLConnectionObserver

/// A ``NetworkObserver`` that periodically pings a URL to infer network connectivity.
///
/// The observer periodically pings a URL to determine the current network connection status based
/// on a `Duration` and `Clock` that you specify.
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public final class URLConnectionObserver: NetworkObserver, Sendable {
  private struct State: Sendable {
    var currentStatus = NetworkConnectionStatus.connected
    var task: Task<Void, Never>?
  }

  private let observe: @Sendable (URLConnectionObserver) async -> Void

  private let state = Lock(State())
  private let subscriptions = OperationSubscriptions<@Sendable (NetworkConnectionStatus) -> Void>()

  /// True if the observer is actively pinging the URL.
  public var isRunning: Bool {
    self.state.withLock { $0.task != nil }
  }

  public init<C: Clock>(
    session: URLSession = .operationConnectivity,
    url: URL = .operationURLConnectionObserverDefault,
    clock: C = ContinuousClock(),
    pingingEvery interval: Duration = .seconds(120)
  ) where C.Duration == Duration {
    self.observe = { observer in
      await observer.ping(to: url, using: session)
      for await _ in _AsyncTimerSequence(interval: interval, clock: clock) {
        await observer.ping(to: url, using: session)
      }
    }
  }

  /// Starts pinging the URL at the specified interval with the specified `URLSession` and `Clock`.
  public func start() {
    self.state.withLock {
      $0.task?.cancel()
      $0.task = Task { [weak self] in
        guard let self else { return }
        await self.observe(self)
      }
    }
  }

  /// Stops pinging the URL.
  public func stop() {
    self.state.withLock { state in
      state.task?.cancel()
      state.task = nil
    }
  }

  deinit {
    self.stop()
  }

  public var currentStatus: NetworkConnectionStatus {
    self.state.withLock { $0.currentStatus }
  }

  public func subscribe(
    with handler: @escaping @Sendable (NetworkConnectionStatus) -> Void
  ) -> OperationSubscription {
    let subscription = self.subscriptions.add(handler: handler).subscription
    handler(self.currentStatus)
    if !self.isRunning {
      self.start()
    }
    return subscription
  }

  private func ping(to url: URL, using session: URLSession) async {
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"

    let status = await self.status(for: request, using: session)

    self.state.withLock { state in
      guard status != state.currentStatus else { return }
      state.currentStatus = status
      self.subscriptions.forEach { $0(status) }
    }
  }

  private func status(
    for request: URLRequest,
    using session: URLSession
  ) async -> NetworkConnectionStatus {
    do {
      _ = try await session.data(for: request)
      return .connected
    } catch {
      return self.isProblematicConnectionError(error) ? .disconnected : .connected
    }
  }

  private func isProblematicConnectionError(_ error: any Error) -> Bool {
    guard let error = error as? URLError else { return false }

    return switch error.code {
    case .notConnectedToInternet,
      .networkConnectionLost,
      .timedOut,
      .internationalRoamingOff,
      .callIsActive,
      .dataNotAllowed:
      true
    default:
      false
    }
  }
}

// MARK: - Starting

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension URLConnectionObserver {
  /// Creates an observer and starts pinging the URL.
  ///
  /// - Parameters:
  ///   - session: The URL session to use for pinging.
  ///   - url: The URL to ping.
  ///   - clock: The clock to use for timing.
  ///   - interval: The interval between pings.
  /// - Returns: A running `URLConnectionObserver`.
  public static func starting<C: Clock>(
    session: URLSession = .operationConnectivity,
    url: URL = .operationURLConnectionObserverDefault,
    clock: C = ContinuousClock(),
    pingingEvery interval: Duration = .seconds(120)
  ) -> URLConnectionObserver where C.Duration == Duration {
    let observer = URLConnectionObserver(
      session: session,
      url: url,
      clock: clock,
      pingingEvery: interval
    )
    observer.start()
    return observer
  }
}

// MARK: - Shared

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension URLConnectionObserver {
  private static let _shared = Lock<URLConnectionObserver?>(nil)

  /// A shared observer instance that pings the default URL.
  public static var shared: URLConnectionObserver {
    Self._shared.withLock { observer in
      if let observer {
        return observer
      }
      observer = URLConnectionObserver()
      return observer!
    }
  }

  /// Creates a shared observer instance and starts pinging the URL.
  ///
  /// ``isRunning`` will be true on the returned instance.
  ///
  /// - Returns: A shared instance of `URLConnectionObserver`.
  public static func startingShared() -> URLConnectionObserver {
    let shared = Self.shared
    if !shared.isRunning {
      shared.start()
    }
    return shared
  }
}

// MARK: - Connectivity Helpers

extension URLSession {
  /// A URL session configured for use with ``URLConnectionObserver``.
  public static let operationConnectivity: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 5
    configuration.httpCookieStorage = nil
    configuration.urlCache = nil
    configuration.allowsCellularAccess = true
    #if canImport(Darwin)
      configuration.allowsConstrainedNetworkAccess = true
      configuration.allowsExpensiveNetworkAccess = true
      if #available(watchOS 11.4, macOS 15.4, iOS 18, tvOS 18, *) {
        configuration.usesClassicLoadingMode = false
      }
    #endif
    return URLSession(configuration: configuration)
  }()
}

extension URL {
  /// The default URL used by ``URLConnectionObserver`` to check the ``NetworkConnectionStatus``.
  public static let operationURLConnectionObserverDefault = URL(
    string: "https://www.apple.com/library/test/success.html"
  )!
}
