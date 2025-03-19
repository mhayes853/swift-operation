import Foundation

// MARK: - BackoffFunction

public struct BackoffFunction: Sendable {
  private let delay: @Sendable (_ retryIndex: Int) -> TimeInterval

  public init(_ delay: @escaping @Sendable (_ retryIndex: Int) -> TimeInterval) {
    self.delay = delay
  }
}

extension BackoffFunction {
  public static func linear(delay: TimeInterval) -> Self {
    Self { TimeInterval($0) * delay }
  }

  public static func exponential(delay: TimeInterval) -> Self {
    Self { TimeInterval(pow(delay, Double($0))) }
  }

  public static let noBackoff = Self { _ in 0 }
}

// MARK: - RetryModifier

extension QueryProtocol {
  public func retry(
    limit: Int,
    backoff: BackoffFunction
  ) -> ModifiedQuery<Self, some QueryModifier<Self>> {
    self.modifier(RetryModifier(limit: limit, backoff: backoff))
  }
}

private struct RetryModifier<Query: QueryProtocol>: QueryModifier {
  let limit: Int
  let backoff: BackoffFunction

  func setup(context: inout QueryContext, using query: Query) {
    context.maxRetryIndex = self.limit
    query.setup(context: &context)
  }

  func fetch(in context: QueryContext, using query: Query) async throws -> Query.Value {
    var context = context
    for index in 0..<self.limit {
      do {
        context.retryIndex = index
        return try await query.fetch(in: context)
      } catch {
        continue
      }
    }
    context.retryIndex = self.limit
    return try await query.fetch(in: context)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var retryIndex: Int {
    get { self[RetryIndexKey.self] }
    set { self[RetryIndexKey.self] = newValue }
  }

  private enum RetryIndexKey: Key {
    static let defaultValue = 0
  }

  public var maxRetryIndex: Int {
    get { self[MaxRetryIndexKey.self] }
    set { self[MaxRetryIndexKey.self] = newValue }
  }

  private enum MaxRetryIndexKey: Key {
    static let defaultValue = 0
  }
}
