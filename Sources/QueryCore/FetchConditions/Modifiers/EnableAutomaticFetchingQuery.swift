// MARK: - QueryProtocol

extension QueryRequest {
  /// Disables automatic fetching for this query based on whether or not `isDisabled` is true.
  ///
  /// Automatic fetching is defined as the process of data being fetched from this query without
  /// explicitly calling ``QueryStore/fetch(using:handler:)``. This includes, but not limited to:
  /// 1. Automatically fetching from this query when subscribed to via ``QueryStore/subscribe(with:)-93jyd``.
  /// 2. Automatically fetching from this query when the app re-enters from the background.
  /// 3. Automatically fetching from this query when the user's network connection comes back online.
  /// 4. Automatically fetching from this query via a ``QueryController``.
  /// 5. Automatically fetching from this query via ``refetchOnChange(of:)``.
  ///
  /// When automatic fetching is disabled, you are responsible for manually calling
  /// ``QueryStore/fetch(using:handler:)`` to ensure that your query always has the latest data.
  ///
  /// When you use the default initializer of a ``QueryClient``, automatic fetching is enabled for all
  /// ``QueryRequest`` conformances, and disabled for all ``MutationRequest`` conformances.
  ///
  /// - Parameter isDisabled: Whether or not to disable automatic fetching.
  /// - Returns: A ``ModifiedQuery``.
  public func disableAutomaticFetching(
    _ isDisabled: Bool = true
  ) -> ModifiedQuery<Self, _EnableAutomaticFetchingModifier<Self, AlwaysCondition>> {
    self.enableAutomaticFetching(onlyWhen: .always(!isDisabled))
  }

  /// Enables automatic fetching for this query based on the specified ``FetchCondition``.
  ///
  /// Automatic fetching is defined as the process of data being fetched from this query without
  /// explicitly calling ``QueryStore/fetch(using:handler:)``. This includes, but not limited to:
  /// 1. Automatically fetching from this query when subscribed to via ``QueryStore/subscribe(with:)-93jyd``.
  /// 2. Automatically fetching from this query when the app re-enters from the background.
  /// 3. Automatically fetching from this query when the user's network connection comes back online.
  /// 4. Automatically fetching from this query via a ``QueryController``.
  /// 5. Automatically fetching from this query via ``refetchOnChange(of:)``.
  ///
  /// When automatic fetching is disabled, you are responsible for manually calling
  /// ``QueryStore/fetch(using:handler:)`` to ensure that your query always has the latest data.
  ///
  /// When you use the default initializer of a ``QueryClient``, automatic fetching is enabled for all
  /// ``QueryRequest`` conformances, and disabled for all ``MutationRequest`` conformances.
  ///
  /// - Parameter condition: The ``FetchCondition`` to enable automatic fetching on.
  /// - Returns: A ``ModifiedQuery``.
  public func enableAutomaticFetching<Condition: FetchCondition>(
    onlyWhen condition: Condition
  ) -> ModifiedQuery<Self, _EnableAutomaticFetchingModifier<Self, Condition>> {
    self.modifier(_EnableAutomaticFetchingModifier(condition: condition))
  }
}

public struct _EnableAutomaticFetchingModifier<
  Query: QueryRequest,
  Condition: FetchCondition
>: QueryModifier {
  let condition: any FetchCondition

  public func setup(context: inout QueryContext, using query: Query) {
    context.enableAutomaticFetchingCondition = self.condition
    query.setup(context: &context)
  }

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    try await query.fetch(in: context, with: continuation)
  }
}

// MARK: - QueryContext

extension QueryContext {
  /// The ``FetchCondition`` that determines whether or not automatic fetching is enabled for a
  /// query.
  ///
  /// The default value of this context property is a condition that always returns false.
  /// However, if you use the default initializer of a ``QueryClient``, then the condition will have
  /// a default value of true for all ``QueryRequest`` conformances and false for all
  /// ``MutationRequest`` conformances.
  public var enableAutomaticFetchingCondition: any FetchCondition {
    get { self[EnableAutomaticFetchingKey.self] }
    set { self[EnableAutomaticFetchingKey.self] = newValue }
  }

  private enum EnableAutomaticFetchingKey: Key {
    static var defaultValue: any FetchCondition { .always(false) }
  }
}
