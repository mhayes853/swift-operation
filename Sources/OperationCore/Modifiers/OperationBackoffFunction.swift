import Foundation

// MARK: - OperationBackoffFunction

/// A backoff function to use for retrying queries.
public struct OperationBackoffFunction: Sendable {
  private let _description: @Sendable () -> String
  private let backoff: @Sendable (Int) -> TimeInterval

  /// Creates a backoff function using a closure you specify.
  ///
  /// The current retry index is passed to your closure, and you must compute a `TimeInterval` for
  /// how long the backoff should be (in seconds).
  ///
  /// - Parameters:
  ///    - description: A description of the backoff function.
  ///    - backoff: A closure to compute the backoff.
  public init(
    _ description: @autoclosure @escaping @Sendable () -> String = "Custom",
    _ backoff: @escaping @Sendable (Int) -> TimeInterval
  ) {
    self.backoff = backoff
    self._description = description
  }
}

// MARK: - Constant

extension OperationBackoffFunction {
  /// A backoff function that returns no backoff.
  public static let noBackoff = Self("No Backoff") { _ in 0 }

  /// A constant backoff function that always returns the specified `interval`.
  ///
  /// - Parameter interval: The backoff value/
  /// - Returns: A constant backoff function.
  public static func constant(_ interval: TimeInterval) -> Self {
    Self("Constant \(interval.durationFormatted())") { _ in interval }
  }
}

// MARK: - Exponential

extension OperationBackoffFunction {
  /// An exponential backoff function.
  ///
  /// - Parameter interval: The base interval of backoff.
  /// - Returns: An exponential backoff function.
  public static func exponential(_ interval: TimeInterval) -> Self {
    Self("Exponential every \(interval.durationFormatted())") {
      $0 == 0 ? 0 : interval * pow(2, TimeInterval($0 - 1))
    }
  }
}

// MARK: - Linear

extension OperationBackoffFunction {
  /// A linear backoff function.
  ///
  /// - Parameter interval: The base interval of backoff.
  /// - Returns: A linear backoff function.
  public static func linear(_ interval: TimeInterval) -> Self {
    Self("Linear every \(interval.durationFormatted())") { TimeInterval($0) * interval }
  }
}

// MARK: - Fibonacci

extension OperationBackoffFunction {
  /// A fibonacci backoff function.
  ///
  /// - Parameter interval: The base interval of backoff.
  /// - Returns: A fibonacci backoff function.
  public static func fibonacci(_ interval: TimeInterval) -> Self {
    Self("Fibonacci every \(interval.durationFormatted())") {
      TimeInterval(OperationCore.fibonacci($0)) * interval
    }
  }
}

// MARK: - Jittered

extension OperationBackoffFunction {
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
    return Self("\(self.rawDescription) with jitter") { attempt in
      generator.inner.withLock { TimeInterval.random(in: 0..<self(attempt), using: &$0) }
    }
  }
}

// MARK: - CallAsFunction

extension OperationBackoffFunction {
  /// Returns the backoff value for the specified retry attempt.
  ///
  /// You should call this function directly, as Swift treats methods named `callAsFunction`
  /// specially. Instead, you can call your instance of `OperationBackoffFunction` as if it was a
  /// function.
  ///
  /// ```swift
  /// let backoff = OperationBackoffFunction.fibonacci(1000)
  /// let delay = backoff(2)
  /// ```
  ///
  /// - Parameter attempt: The current retry attempt.
  /// - Returns: A `TimeInterval` for how long a query should wait before the next attempt.
  public func callAsFunction(_ attempt: Int) -> TimeInterval {
    self.backoff(attempt)
  }
}

// MARK: - CustomStringConvertible

extension OperationBackoffFunction: CustomStringConvertible {
  public var description: String {
    "OperationBackoffFunction(\(self.rawDescription))"
  }

  /// The description of this backoff function without any additional formatting.
  public var rawDescription: String {
    self._description()
  }
}

// MARK: - QueryModifier

extension QueryRequest {
  /// Sets the ``OperationBackoffFunction`` to use for this query.
  ///
  /// - Parameter function: The ``OperationBackoffFunction`` to use.
  /// - Returns: A ``ModifiedQuery``.
  public func backoff(
    _ function: OperationBackoffFunction
  ) -> ModifiedQuery<Self, _OperationBackoffFunctionModifier<Self>> {
    self.modifier(_OperationBackoffFunctionModifier(function: function))
  }
}

public struct _OperationBackoffFunctionModifier<
  Query: QueryRequest
>: _ContextUpdatingQueryModifier {
  let function: OperationBackoffFunction

  public func setup(context: inout OperationContext) {
    context.operationBackoffFunction = self.function
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The current ``OperationBackoffFunction`` in this context.
  ///
  /// The default value is ``OperationBackoffFunction/exponential(_:)`` with a base interval of 1 second.
  public var operationBackoffFunction: OperationBackoffFunction {
    get { self[OperationBackoffFunctionKey.self] }
    set { self[OperationBackoffFunctionKey.self] = newValue }
  }

  private enum OperationBackoffFunctionKey: Key {
    static var defaultValue: OperationBackoffFunction { .exponential(1) }
  }
}
