import IssueReporting
import QueryCore

#if SwiftQueryWebBrowser
  import QueryBrowser
#endif

// MARK: - Default Init

extension QueryClient {
  /// Creates a client.
  ///
  /// - Parameters:
  ///   - defaultContext: The default ``QueryContext`` to use for each ``QueryStore`` created by the client.
  ///   - storeCache: The ``StoreCache`` to use.
  public convenience init(
    defaultContext: QueryContext = QueryContext(),
    storeCache: some StoreCache = DefaultStoreCache()
  ) {
    self.init(
      defaultContext: defaultContext,
      storeCache: storeCache,
      storeCreator: isTesting ? .defaultTesting : .default()
    )
  }
}

// MARK: - DefaultStoreCreator

extension QueryClient {
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
    let retryBackoff: QueryBackoffFunction?
    let retryDelayer: (any QueryDelayer)?
    let queryEnableAutomaticFetchingCondition: any FetchCondition
    let networkObserver: (any NetworkObserver)?
    let activityObserver: (any ApplicationActivityObserver)?

    public func store<Query: QueryRequest>(
      for query: Query,
      in context: QueryContext,
      with initialState: Query.State
    ) -> QueryStore<Query.State> {
      if query is any MutationRequest {
        return .detached(
          query: query.retry(
            limit: self.retryLimit,
            backoff: self.retryBackoff,
            delayer: self.retryDelayer
          ),
          initialState: initialState,
          initialContext: context
        )
      }
      return .detached(
        query:
          query.retry(
            limit: self.retryLimit,
            backoff: self.retryBackoff,
            delayer: self.retryDelayer
          )
          .enableAutomaticFetching(
            onlyWhen: AnyFetchCondition(self.queryEnableAutomaticFetchingCondition)
          )
          .refetchOnChange(of: self.refetchOnChangeCondition)
          .deduplicated(),
        initialState: initialState,
        initialContext: context
      )
    }

    private var refetchOnChangeCondition: AnyFetchCondition {
      switch (self.networkObserver, self.activityObserver) {
      case (let networkObserver?, let activityObserver?):
        return AnyFetchCondition(
          .connected(to: networkObserver) && .applicationIsActive(observer: activityObserver)
        )
      case (let networkObserver?, _):
        return AnyFetchCondition(.connected(to: networkObserver))
      case (_, let activityObserver?):
        return AnyFetchCondition(.applicationIsActive(observer: activityObserver))
      default:
        return AnyFetchCondition(.always(false))
      }
    }
  }
}

extension QueryClient.StoreCreator where Self == QueryClient.DefaultStoreCreator {
  /// The default `StoreCreator` used by a query client for testing.
  ///
  /// In testing, retries are disabled, and the network status and application activity status are
  /// not observed.
  public static var defaultTesting: Self {
    .default(
      retryLimit: 0,
      retryBackoff: .noBackoff,
      retryDelayer: .noDelay,
      queryEnableAutomaticFetchingCondition: .always(true),
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
  ///   - retryBackoff: The backoff function to use for retries.
  ///   - retryDelayer: The `QueryDelayer` to use for delaying the execution of a retry.
  ///   - queryEnableAutomaticFetchingCondition: The default `FetchCondition` that determines
  ///   whether or not automatic fetching is enabled for queries (and not mutations).
  ///   - networkObserver: The default `NetworkObserver` to use.
  ///   - activityObserver: The default `ApplicationActivityObserver` to use.
  /// - Returns: A ``QueryCore/QueryClient/DefaultStoreCreator``.
  public static func `default`(
    retryLimit: Int = 3,
    retryBackoff: QueryBackoffFunction? = nil,
    retryDelayer: (any QueryDelayer)? = nil,
    queryEnableAutomaticFetchingCondition: any FetchCondition = .always(true),
    networkObserver: (any NetworkObserver)? = QueryClient.defaultNetworkObserver,
    activityObserver: (any ApplicationActivityObserver)? = QueryClient
      .defaultApplicationActivityObserver
  ) -> Self {
    Self(
      retryLimit: retryLimit,
      retryBackoff: retryBackoff,
      retryDelayer: retryDelayer,
      queryEnableAutomaticFetchingCondition: queryEnableAutomaticFetchingCondition,
      networkObserver: networkObserver,
      activityObserver: activityObserver
    )
  }
}

// MARK: - Defaults

extension QueryClient {
  /// The default ``NetworkObserver`` to use for observing the user's connection status.
  ///
  /// - On Darwin platforms, `NWPathMonitorObserver` is used.
  /// - On Broswer platforms (WASI), `NavigatorObserver` is used.
  /// - On other platforms, the value is nil.
  public static var defaultNetworkObserver: (any NetworkObserver)? {
    #if canImport(Network)
      NWPathMonitorObserver.shared
    #elseif SwiftQueryWebBrowser
      NavigatorObserver.shared
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
    #elseif SwiftQueryWebBrowser
      WindowVisibilityObserver.shared
    #else
      nil
    #endif
  }
}
