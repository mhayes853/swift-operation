import IssueReporting
import QueryCore

#if browser
  import QueryBrowser
#endif

// MARK: - Default Init

extension QueryClient {
  public convenience init(defaultContext: QueryContext = QueryContext()) {
    self.init(
      defaultContext: defaultContext,
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
    let focusCondition: (any FetchCondition)?

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
      switch (self.networkObserver, self.focusCondition) {
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
      focusCondition: nil
    )
  }

  public static func `default`(
    retryLimit: Int = 3,
    retryBackoff: QueryBackoffFunction? = nil,
    retryDelayer: (any QueryDelayer)? = nil,
    queryEnableAutomaticFetchingCondition: any FetchCondition = .always(true),
    networkObserver: (any NetworkObserver)? = defaultNetworkObserver,
    focusCondition: (any FetchCondition)? = defaultFocusCondition
  ) -> Self {
    Self(
      retryLimit: retryLimit,
      retryBackoff: retryBackoff,
      retryDelayer: retryDelayer,
      queryEnableAutomaticFetchingCondition: queryEnableAutomaticFetchingCondition,
      networkObserver: networkObserver,
      focusCondition: focusCondition
    )
  }
}

/// The default ``NetworkObserver`` to use for observing the user's connection status.
///
/// - On Darwin platforms, `NWPathMonitorObserver.shared` is used.
/// - On Broswer platforms (WASI), `NavigatorObserver.shared` is used.
/// - On other platforms, the value is nil.
public var defaultNetworkObserver: (any NetworkObserver)? {
  #if canImport(Network)
    NWPathMonitorObserver.shared
  #elseif canImport(JavaScriptKit)
    NavigatorObserver.shared
  #else
    nil
  #endif
}

/// The default ``FetchCondition`` to use for detetcing whether or not the app is active.
///
/// - On Darwin platforms, the ``FetchCondition/notificationFocus`` condition is used.
/// - On Broswer platforms (WASI), the ``FetchCondition/windowFocus`` condition is used.
/// - On other platforms, the value is nil.
public var defaultFocusCondition: (any FetchCondition)? {
  #if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)
    .notificationFocus
  #elseif os(watchOS)
    if #available(watchOS 7.0, *) {
      .notificationFocus
    } else {
      nil
    }
  #elseif canImport(JavaScriptKit)
    .windowFocus
  #else
    nil
  #endif
}
