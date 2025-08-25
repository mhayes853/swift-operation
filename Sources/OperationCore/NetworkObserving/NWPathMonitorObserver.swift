#if canImport(Network)
  import Network

  // MARK: - NWPathMonitorObserver

  /// A ``NetworkObserver`` that utilizes `NWPathMonitor` to observe an interface's connection
  /// status.
  public final class NWPathMonitorObserver {
    private typealias Handler = @Sendable (NetworkConnectionStatus) -> Void

    private let monitor: NWPathMonitor
    private let subscriptions = QuerySubscriptions<Handler>()

    private init(monitor: NWPathMonitor) {
      self.monitor = monitor
    }

    /// Creates a path monitor observer, and begins observing path updates.
    ///
    /// This initializer updates the `pathUpdateHandler` of the specifed `monitor` by first calling
    /// out to the current handler, and then by propagating the new path status to all subscribers
    /// on this observer.
    ///
    /// When the observer is deallocated, it will cancel the path monitor.
    ///
    /// - Parameters:
    ///   - monitor: The `NWPathMonitor` to use.
    ///   - queue: The queue to start monitoring for updates on.
    public static func starting(
      monitor: NWPathMonitor = NWPathMonitor(),
      queue: DispatchQueue = .global()
    ) -> NWPathMonitorObserver {
      let observer = NWPathMonitorObserver(monitor: monitor)
      let previousHandler = monitor.pathUpdateHandler
      monitor.pathUpdateHandler = { [weak observer] path in
        previousHandler?(path)
        observer?.subscriptions.forEach { $0(NetworkConnectionStatus(path.status)) }
      }
      monitor.start(queue: queue)
      return observer
    }

    deinit { self.monitor.cancel() }
  }

  // MARK: - Starting Shared

  extension NWPathMonitorObserver {
    private static let shared = Lock<NWPathMonitorObserver?>(nil)

    /// Creates a shared path monitor observer instance that starts monitoring all available network interfaces.
    ///
    /// - Returns: A shared instance of `NWPathMonitorObserver`.
    public static func startingShared() -> NWPathMonitorObserver {
      Self.shared.withLock { observer in
        if let observer {
          return observer
        }
        observer = .starting()
        return observer!
      }
    }
  }

  // MARK: - NetworkObserver Conformance

  extension NWPathMonitorObserver: NetworkObserver {
    public var currentStatus: NetworkConnectionStatus {
      NetworkConnectionStatus(self.monitor.currentPath.status)
    }

    public func subscribe(
      with handler: @escaping @Sendable (NetworkConnectionStatus) -> Void
    ) -> QuerySubscription {
      self.subscriptions.add(handler: handler).subscription
    }
  }

  // MARK: - Helpers

  extension NetworkConnectionStatus {
    fileprivate init(_ status: NWPath.Status) {
      switch status {
      case .satisfied:
        self = .connected
      case .unsatisfied:
        self = .disconnected
      case .requiresConnection:
        self = .requiresConnection
      @unknown default:
        self = .connected
      }
    }
  }
#endif
