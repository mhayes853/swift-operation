import IssueReporting
import QueryCore

#if SwiftQueryWebBrowser
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

  /// The default ``ApplicationActivityObserver`` to use for detetcing whether or not the app is active.
  ///
  /// - On Darwin platforms, the underlying `XXXApplication` class is used.
  /// - On Broswer platforms (WASI), the `WindowVisibilityObserver` is used.
  /// - On other platforms, the value is nil.
  public static var defaultApplicationActivityObserver: (any ApplicationActivityObserver)? {
    #if os(iOS) || os(tvOS) || os(visionOS)
      .uiApplication
    #elseif os(macOS)
      .nsApplication
    #elseif os(watchOS)
      if #available(watchOS 7.0, *) {
        .wkApplication
      } else {
        nil
      }
    #elseif WebBrowser && canImport(JavaScriptKit)
      .windowVisibility
    #else
      nil
    #endif
  }
}
