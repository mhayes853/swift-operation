#if canImport(Network)
  import Network

  // MARK: - NWPathMonitorObserver

  /// A ``NetworkObserver`` that utilizes `NWPathMonitor` to observe an interface's connection
  /// status.
  public final class NWPathMonitorObserver {
    private typealias Handler = @Sendable (NetworkStatus) -> Void

    private let monitor: NWPathMonitor
    private let subscriptions = QuerySubscriptions<Handler>()
    private let queue: DispatchQueue
    
    /// Creates a path monitor observer.
    ///
    /// This initializer updates the `pathUpdateHandler` of the specifed `monitor` by first calling
    /// out to the current handler, and then by propagating the new path status to all subscribers
    /// on this observer.
    ///
    /// - Parameters:
    ///   - monitor: The `NWPathMonitor` to use.
    ///   - queue: The queue to start monitoring for updates on.
    public init(monitor: NWPathMonitor = NWPathMonitor(), queue: DispatchQueue = .global()) {
      self.monitor = monitor
      self.queue = queue
      let previousHandler = self.monitor.pathUpdateHandler
      self.monitor.pathUpdateHandler = { [weak self] path in
        guard let self else { return }
        previousHandler?(path)
        self.subscriptions.forEach { $0(NetworkStatus(path.status)) }
      }
    }
  }

  // MARK: - NetworkObserver Conformance

  extension NWPathMonitorObserver: NetworkObserver {
    public var currentStatus: NetworkStatus {
      NetworkStatus(self.monitor.currentPath.status)
    }

    public func subscribe(
      with handler: @escaping @Sendable (NetworkStatus) -> Void
    ) -> QuerySubscription {
      let (subscription, isFirst) = self.subscriptions.add(handler: handler)
      if isFirst {
        self.monitor.start(queue: self.queue)
      }
      return QuerySubscription { [weak self] in
        subscription.cancel()
        if self?.subscriptions.count == 0 {
          self?.monitor.cancel()
        }
      }
    }
  }

  // MARK: - Shared Instance

  extension NWPathMonitorObserver {
    /// A shared ``NWPathMonitorObserver`` instance that observes all available interface types.
    public static let shared = NWPathMonitorObserver()
  }

  // MARK: - Helpers

  extension NetworkStatus {
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
