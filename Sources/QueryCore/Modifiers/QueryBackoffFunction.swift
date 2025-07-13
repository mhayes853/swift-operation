import Foundation

// MARK: - QueryBackoffFunction

/// A backoff function to use for retrying queries.
public struct QueryBackoffFunction: Sendable {
  private let backoff: @Sendable (Int) -> TimeInterval

  /// Creates a backoff function using a closure you specify.
  ///
  /// The current retry index is passed to your closure, and you must compute a `TimeInterval` for
  /// how long the backoff should be (in seconds).
  ///
  /// - Parameter backoff: A closure to compute the backoff.
  public init(_ backoff: @escaping @Sendable (Int) -> TimeInterval) {
    self.backoff = backoff
  }
}

// MARK: - Constant

extension QueryBackoffFunction {
  /// A backoff function that returns no backoff.
  public static let noBackoff = Self.constant(0)

  /// A constant backoff function that always returns the specified `interval`.
  ///
  /// - Parameter interval: The backoff value/
  /// - Returns: A constant backoff function.
  public static func constant(_ interval: TimeInterval) -> Self {
    Self { _ in interval }
  }
}

// MARK: - Exponential

extension QueryBackoffFunction {
  /// An exponential backoff function.
  ///
  /// - Parameter interval: The base interval of backoff.
  /// - Returns: An exponential backoff function.
  public static func exponential(_ interval: TimeInterval) -> Self {
    Self { $0 == 0 ? 0 : interval * pow(2, TimeInterval($0 - 1)) }
  }
}

// MARK: - Linear

extension QueryBackoffFunction {
  /// A linear backoff function.
  ///
  /// - Parameter interval: The base interval of backoff.
  /// - Returns: A linear backoff function.
  public static func linear(_ interval: TimeInterval) -> Self {
    Self { TimeInterval($0) * interval }
  }
}

// MARK: - Fibonacci

extension QueryBackoffFunction {
  /// A fibonacci backoff function.
  ///
  /// - Parameter interval: The base interval of backoff.
  /// - Returns: A fibonacci backoff function.
  public static func fibonacci(_ interval: TimeInterval) -> Self {
    Self { TimeInterval(QueryCore.fibonacci($0)) * interval }
  }
}

// MARK: - Jittered

extension QueryBackoffFunction {
  /// Adds a jitter to this backoff function.
  ///
  /// Using a jitter will randomize the backoff value that is returned from the function in the
  /// range [0, whatever the backoff function returns]. This ensures that many concurrently
  /// running queries do not overload a server as a thundering herd when retrying.
  ///
  /// - Parameter generator: A `RandomNumberGenerator` to use for computing jitter values.
  /// - Returns: This backoff function with jitter applied.
  public func jittered<T: RandomNumberGenerator & Sendable>(
    using generator: T = SystemRandomNumberGenerator()
  ) -> Self {
    let generator = LockedBox(value: generator)
    return Self { attempt in
      generator.inner.withLock { TimeInterval.random(in: 0..<self(attempt), using: &$0) }
    }
  }
}

// MARK: - CallAsFunction

extension QueryBackoffFunction {
  /// Returns the backoff value for the specified retry attempt.
  ///
  /// You should call this function directly, as Swift treats methods named `callAsFunction`
  /// specially. Instead, you can call your instance of `QueryBackoffFunction` as if it was a
  /// function.
  ///
  /// ```swift
  /// let backoff = QueryBackoffFunction.fibonacci(1000)
  /// let delay = backoff(2)
  /// ```
  ///
  /// - Parameter attempt: The current retry attempt.
  /// - Returns: A `TimeInterval` for how long a query should wait before the next attempt.
  public func callAsFunction(_ attempt: Int) -> TimeInterval {
    self.backoff(attempt)
  }
}

// MARK: - QueryModifier

extension QueryRequest {
  /// Sets the ``QueryBackoffFunction`` to use for this query.
  ///
  /// - Parameter function: The ``QueryBackoffFunction`` to use.
  /// - Returns: A ``ModifiedQuery``.
  public func backoff(
    _ function: QueryBackoffFunction
  ) -> ModifiedQuery<Self, _BackoffFunctionModifier<Self>> {
    self.modifier(_BackoffFunctionModifier(function: function))
  }
}

public struct _BackoffFunctionModifier<Query: QueryRequest>: _ContextUpdatingQueryModifier {
  let function: QueryBackoffFunction

  public func setup(context: inout QueryContext) {
    context.queryBackoffFunction = self.function
  }
}

// MARK: - QueryContext

extension QueryContext {
  /// The current ``QueryBackoffFunction`` in this context.
  ///
  /// The default value is ``QueryBackoffFunction/exponential(_:)`` with a base interval of 1 second.
  public var queryBackoffFunction: QueryBackoffFunction {
    get { self[QueryBackoffFunctionKey.self] }
    set { self[QueryBackoffFunctionKey.self] = newValue }
  }

  private enum QueryBackoffFunctionKey: Key {
    static var defaultValue: QueryBackoffFunction { .exponential(1) }
  }
}
