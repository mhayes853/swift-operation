#if canImport(Network)
  import Network

  public final class NWPathMonitorObserver: NetworkObserver {
    private typealias Handler = @Sendable (NetworkStatus) -> Void

    private let monitor: NWPathMonitor
    private let subscriptions = QuerySubscriptions<Handler>()
    private let queue: DispatchQueue

    public init(monitor: NWPathMonitor = NWPathMonitor(), queue: DispatchQueue = .global()) {
      self.monitor = monitor
      self.queue = queue
      let currentHandler = self.monitor.pathUpdateHandler
      self.monitor.pathUpdateHandler = { [weak self] path in
        guard let self else { return }
        currentHandler?(path)
        self.subscriptions.forEach { $0(NetworkStatus(path.status)) }
      }
    }

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
