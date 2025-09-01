import IssueReporting
import OperationCore

#if SwiftOperationWebBrowser
  import OperationWebBrowser
#endif

// MARK: - Default Init

extension OperationClient {
  /// Creates a client.
  ///
  /// - Parameters:
  ///   - defaultContext: The default ``OperationContext`` to use for each ``OperationStore`` created by the client.
  ///   - storeCache: The ``StoreCache`` to use.
  public convenience init(
    defaultContext: OperationContext = OperationContext(),
    storeCache: sending some StoreCache = DefaultStoreCache()
  ) {
    self.init(
      defaultContext: defaultContext,
      storeCache: storeCache,
      storeCreator: isTesting ? .defaultTesting : .default()
    )
  }
}

// MARK: - DefaultStoreCreator

extension OperationClient {
  /// The default `StoreCreator` used by a query client.
  ///
  /// This store creator applies a set of default modifiers to both `QueryRequest` and
  /// `MutationRequest` instances.
  ///
  /// **Queries**
  /// - Deduplication
  /// - Retries
  /// - Automatic Fetching
  /// - Refetching when the network comes back online
  /// - Refetching when the app reenters from the background
  ///
  /// **Mutations**
  /// - Retries
  public struct DefaultStoreCreator: StoreCreator {
    let retryLimit: Int
    let backoff: OperationBackoffFunction?
    let delayer: (any OperationDelayer)?
    let automaticRunningSpecification: any OperationRunSpecification & Sendable
    let networkObserver: (any NetworkObserver & Sendable)?
    let activityObserver: (any ApplicationActivityObserver)?

    public func store<Operation: OperationRequest & Sendable>(
      for operation: Operation,
      in context: OperationContext,
      with initialState: Operation.State
    ) -> OperationStore<Operation.State> {
      let backoff = self.backoff ?? context.operationBackoffFunction
      let delayer = AnyDelayer(self.delayer ?? context.operationDelayer)
      if operation is any MutationRequest {
        return .detached(
          operation:
            operation.retry(limit: self.retryLimit)
            .backoff(backoff)
            .delayer(delayer),
          initialState: initialState,
          initialContext: context
        )
      }
      return .detached(
        operation:
          operation.retry(limit: self.retryLimit)
          .backoff(backoff)
          .delayer(delayer)
          .enableAutomaticRunning(
            onlyWhen: AnySendableRunSpecification(self.automaticRunningSpecification)
          )
          .rerunOnChange(of: self.refetchOnChangeCondition)
          .deduplicated(),
        initialState: initialState,
        initialContext: context
      )
    }

    private var refetchOnChangeCondition: AnySendableRunSpecification {
      switch (self.networkObserver, self.activityObserver) {
      case (let networkObserver?, let activityObserver?):
        return AnySendableRunSpecification(
          NetworkConnectionRunSpecification(observer: AnySendableNetworkObserver(networkObserver))
            && ApplicationIsActiveRunSpecification(observer: activityObserver)
        )
      case (let networkObserver?, _):
        return AnySendableRunSpecification(
          NetworkConnectionRunSpecification(observer: AnySendableNetworkObserver(networkObserver))
        )
      case (_, let activityObserver?):
        return AnySendableRunSpecification(
          ApplicationIsActiveRunSpecification(observer: activityObserver)
        )
      default:
        return AnySendableRunSpecification(AlwaysRunSpecification(isTrue: false))
      }
    }
  }
}

extension OperationClient.StoreCreator where Self == OperationClient.DefaultStoreCreator {
  /// The default `StoreCreator` used by a query client for testing.
  ///
  /// In testing, retries are disabled, and the network status and application activity status are
  /// not observed, delays are disabled, and the backoff function is `OperationBackoffFunction.noBackoff`.
  public static var defaultTesting: Self {
    .default(
      retryLimit: 0,
      backoff: .noBackoff,
      delayer: .noDelay,
      automaticRunningSpecification: AlwaysRunSpecification(isTrue: true),
      networkObserver: nil,
      activityObserver: nil
    )
  }

  /// The default `StoreCreator` used by a query client.
  ///
  /// This store creator applies a set of default modifiers to both `QueryRequest` and
  /// `MutationRequest` instances.
  ///
  /// **Queries**
  /// - Deduplication
  /// - Retries
  /// - Automatic Fetching
  /// - Refetching when the network comes back online
  /// - Refetching when the app reenters from the background
  ///
  /// **Mutations**
  /// - Retries
  ///
  /// - Parameters:
  ///   - retryLimit: The maximum number of retries for queries and mutations.
  ///   - backoff: The backoff function to use for retries.
  ///   - delayer: The `QueryDelayer` to use for delaying the execution of a retry.
  ///   - queryEnableAutomaticFetchingCondition: The default `FetchCondition` that determines
  ///   whether or not automatic fetching is enabled for queries (and not mutations).
  ///   - networkObserver: The default `NetworkObserver` to use.
  ///   - activityObserver: The default `ApplicationActivityObserver` to use.
  /// - Returns: A ``QueryCore/OperationClient/DefaultStoreCreator``.
  public static func `default`(
    retryLimit: Int = 3,
    backoff: OperationBackoffFunction? = nil,
    delayer: (any OperationDelayer)? = nil,
    automaticRunningSpecification: any OperationRunSpecification & Sendable =
      AlwaysRunSpecification(isTrue: true),
    networkObserver: (any NetworkObserver & Sendable)? = OperationClient.defaultNetworkObserver,
    activityObserver: (any ApplicationActivityObserver)? = OperationClient
      .defaultApplicationActivityObserver
  ) -> Self {
    Self(
      retryLimit: retryLimit,
      backoff: backoff,
      delayer: delayer,
      automaticRunningSpecification: automaticRunningSpecification,
      networkObserver: networkObserver,
      activityObserver: activityObserver
    )
  }
}

// MARK: - Defaults

extension OperationClient {
  /// The default ``NetworkObserver`` to use for observing the user's connection status.
  ///
  /// - On Darwin platforms, `NWPathMonitorObserver` is used.
  /// - On Broswer platforms (WASI), `NavigatorOnlineObserver` is used.
  /// - On other platforms, the value is nil.
  public static var defaultNetworkObserver: (any NetworkObserver & Sendable)? {
    #if canImport(Network)
      NWPathMonitorObserver.startingShared()
    #elseif SwiftQueryWebBrowser && canImport(JavaScriptKit)
      NavigatorOnlineObserver.shared
    #else
      nil
    #endif
  }

  /// The default ``ApplicationActivityObserver`` to use for detetcing whether or not the app is active.
  ///
  /// - On Darwin platforms, the underlying `XXXApplication` class is used.
  /// - On Broswer platforms (WASI), the `WindowVisibilityObserver` is used.
  /// - On other platforms, the value is nil.
  public static var defaultApplicationActivityObserver: (any ApplicationActivityObserver)? {
    #if os(iOS) || os(tvOS) || os(visionOS)
      UIApplicationActivityObserver.shared
    #elseif os(macOS)
      NSApplicationActivityObserver.shared
    #elseif os(watchOS)
      if #available(watchOS 7.0, *) {
        WKApplicationActivityObserver.shared
      } else {
        nil
      }
    #elseif SwiftQueryWebBrowser && canImport(JavaScriptKit)
      WindowVisibilityObserver.shared
    #else
      nil
    #endif
  }
}
