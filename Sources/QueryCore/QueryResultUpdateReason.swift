// MARK: - QueryResultUpdateReason

/// A reason that a query yielded a result.
///
/// You can check the reason from within the ``QueryEventHandler/onResultReceived`` callback.
///
/// ```swift
/// let handler = QueryEventHandler<MyQuery.State> { state, context in
///   // ...
/// } onResultReceived: { result, context in
///   guard context.queryResultUpdateReason == .returnedFinalResult else { return }
///   // ...
/// }
/// ```
public struct QueryResultUpdateReason: Hashable, Sendable {
  private let rawValue: String
}

extension QueryResultUpdateReason {
  /// The query yielded a result through a ``QueryContinuation``.
  public static let yieldedResult = Self(rawValue: "yieldedResult")
  
  /// The query returned its final value from ``QueryRequest/fetch(in:with:)``.
  public static let returnedFinalResult = Self(rawValue: "returnedFinalResult")
}

extension QueryResultUpdateReason: CustomStringConvertible {
  public var description: String {
    self.rawValue
  }
}

// MARK: - QueryContext

extension QueryContext {
  /// The current ``QueryResultUpdateReason`` in this context.
  ///
  /// This value is non-nil when accessed from within the ``QueryEventHandler/onResultReceived``
  /// callback.
  public var queryResultUpdateReason: QueryResultUpdateReason? {
    get { self[QueryResultUpdateReasonKey.self] }
    set { self[QueryResultUpdateReasonKey.self] = newValue }
  }

  private enum QueryResultUpdateReasonKey: Key {
    static let defaultValue: QueryResultUpdateReason? = nil
  }
}
