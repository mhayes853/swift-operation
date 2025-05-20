import IssueReporting
import QueryCore

#if WebBrowser
  import QueryBrowser
#endif

// MARK: - Default Init

extension QueryClient {
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
  public struct DefaultStoreCreator: StoreCreator {
    let retryLimit: Int
    let retryBackoff: QueryBackoffFunction?
    let retryDelayer: (any QueryDelayer)?
    let queryEnableAutomaticFetchingCondition: any FetchCondition
    let networkObserver: (any NetworkObserver)?
    let appActiveCondition: (any FetchCondition)?

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
      switch (self.networkObserver, self.appActiveCondition) {
      case (let observer?, let focusCondition?):
        return AnyFetchCondition(.connected(to: observer) && AnyFetchCondition(focusCondition))
      case (let observer?, _):
        return AnyFetchCondition(.connected(to: observer))
      case (_, let focusCondition?):
        return AnyFetchCondition(focusCondition)
      default:
        return AnyFetchCondition(.always(false))
      }
    }
  }
}

extension QueryClient.StoreCreator where Self == QueryClient.DefaultStoreCreator {
  public static var defaultTesting: Self {
    .default(
      retryLimit: 0,
      retryBackoff: .noBackoff,
      retryDelayer: .noDelay,
      queryEnableAutomaticFetchingCondition: .always(true),
      networkObserver: nil,
      appActiveCondition: nil
    )
  }

  public static func `default`(
    retryLimit: Int = 3,
    retryBackoff: QueryBackoffFunction? = nil,
    retryDelayer: (any QueryDelayer)? = nil,
    queryEnableAutomaticFetchingCondition: any FetchCondition = .always(true),
    networkObserver: (any NetworkObserver)? = QueryClient.defaultNetworkObserver,
    appActiveCondition: (any FetchCondition)? = QueryClient.defaultAppActiveCondition
  ) -> Self {
    Self(
      retryLimit: retryLimit,
      retryBackoff: retryBackoff,
      retryDelayer: retryDelayer,
      queryEnableAutomaticFetchingCondition: queryEnableAutomaticFetchingCondition,
      networkObserver: networkObserver,
      appActiveCondition: appActiveCondition
    )
  }
}

// MARK: - Defaults

extension QueryClient {
  /// The default ``NetworkObserver`` to use for observing the user's connection status.
  ///
  /// - On Darwin platforms, `NWPathMonitorObserver.shared` is used.
  /// - On Broswer platforms (WASI), `NavigatorObserver.shared` is used.
  /// - On other platforms, the value is nil.
  public static var defaultNetworkObserver: (any NetworkObserver)? {
    #if canImport(Network)
      NWPathMonitorObserver.shared
    #elseif WebBrowser && canImport(JavaScriptKit)
      NavigatorObserver.shared
    #else
      nil
    #endif
  }

  /// The default ``FetchCondition`` to use for detetcing whether or not the app is active.
  ///
  /// - On Darwin platforms, the ``FetchCondition/notificationFocus`` condition is used.
  /// - On Broswer platforms (WASI), the `WindowIsVisibleCondition` condition is used.
  /// - On other platforms, the value is nil.
  public static var defaultAppActiveCondition: (any FetchCondition)? {
    nil
  }
}
