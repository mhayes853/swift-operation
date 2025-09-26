#if canImport(Network)
  import Network

  // MARK: - NWPathMonitorObserver

  /// A ``NetworkObserver`` that utilizes `NWPathMonitor` to observe an interface's connection
  /// status.
  public final class NWPathMonitorObserver: NetworkObserver, Sendable {
    private typealias Handler = @Sendable (NetworkConnectionStatus) -> Void

    private let monitor: NWPathMonitor
    private let subscriptions = OperationSubscriptions<Handler>()

    /// True if the observer is actively monitoring network connection status changes.
    public var isRunning: Bool {
      self.monitor.queue != nil
    }
    
    /// Creates an observer.
    ///
    /// - Parameter monitor: The path monitor to use.
    public init(_ monitor: NWPathMonitor = NWPathMonitor()) {
      self.monitor = monitor

      let previousHandler = monitor.pathUpdateHandler
      monitor.pathUpdateHandler = { [weak self] path in
        previousHandler?(path)
        self?.subscriptions.forEach { $0(NetworkConnectionStatus(path.status)) }
      }
    }

    /// Creates a path monitor observer, and starts monitoring network connection status changes.
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
      let observer = NWPathMonitorObserver(monitor)
      observer.start(on: queue)
      return observer
    }

    deinit { self.monitor.cancel() }
    
    /// Starts monitoring for network status changes on the specified queue.
    ///
    /// - Parameter queue: The queue to use to listen to changes.
    public func start(on queue: DispatchQueue) {
      self.monitor.cancel()
      self.monitor.start(queue: queue)
    }
    
    /// Stops listening for network status changes.
    public func stop() {
      self.monitor.cancel()
    }
    
    public var currentStatus: NetworkConnectionStatus {
      NetworkConnectionStatus(self.monitor.currentPath.status)
    }

    public func subscribe(
      with handler: @escaping @Sendable (NetworkConnectionStatus) -> Void
    ) -> OperationSubscription {
      self.subscriptions.add(handler: handler).subscription
    }
  }

  // MARK: - Starting Shared

  extension NWPathMonitorObserver {
    private static let _shared = Lock<NWPathMonitorObserver?>(nil)

    /// A shared path monitor observer instance that monitors all available network interfaces.
    public static var shared: NWPathMonitorObserver {
      Self._shared.withLock { observer in
        if let observer {
          return observer
        }
        observer = NWPathMonitorObserver()
        return observer!
      }
    }

    /// Creates a shared path monitor observer instance that starts monitoring the network
    /// connection status on all available network interfaces.
    ///
    /// ``isRunning`` will be true on the returned instance.
    ///
    /// - Returns: A shared instance of `NWPathMonitorObserver`.
    public static func startingShared() -> NWPathMonitorObserver {
      let shared = Self.shared
      if !shared.isRunning {
        shared.start(on: .global())
      }
      return shared
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
