import Foundation

// MARK: - OperationBackoffFunction

/// A backoff function to use for retrying operations.
public struct OperationBackoffFunction: Sendable {
  private let _description: @Sendable () -> String
  private let backoff: @Sendable (Int) -> OperationDuration

  /// Creates a backoff function using a closure you specify.
  ///
  /// The current retry index is passed to your closure, and you must compute an
  /// ``OperationDuration`` for how long the backoff should be.
  ///
  /// - Parameters:
  ///    - description: A description of the backoff function.
  ///    - backoff: A closure to compute the backoff.
  public init(
    _ description: @autoclosure @escaping @Sendable () -> String = "Custom",
    _ backoff: @escaping @Sendable (Int) -> OperationDuration
  ) {
    self.backoff = backoff
    self._description = description
  }
}

// MARK: - Constant

extension OperationBackoffFunction {
  /// A backoff function that returns no backoff.
  public static let noBackoff = Self("No Backoff") { _ in .zero }

  /// A constant backoff function that always returns the specified `duration`.
  ///
  /// - Parameter duration: The backoff value.
  /// - Returns: A constant backoff function.
  public static func constant(_ duration: OperationDuration) -> Self {
    Self("Constant \(duration)") { _ in duration }
  }
}

// MARK: - Exponential

extension OperationBackoffFunction {
  /// An exponential backoff function.
  ///
  /// - Parameter duration: The base duration of backoff.
  /// - Returns: An exponential backoff function.
  public static func exponential(_ duration: OperationDuration) -> Self {
    Self("Exponential every \(duration)") {
      $0 == 0 ? .zero : duration * Int(pow(2, Double($0 - 1)))
    }
  }
}

// MARK: - Linear

extension OperationBackoffFunction {
  /// A linear backoff function.
  ///
  /// - Parameter duration: The base duration of backoff.
  /// - Returns: A linear backoff function.
  public static func linear(_ duration: OperationDuration) -> Self {
    Self("Linear every \(duration)") { duration * $0 }
  }
}

// MARK: - Fibonacci

extension OperationBackoffFunction {
  /// A fibonacci backoff function.
  ///
  /// - Parameter duration: The base duration of backoff.
  /// - Returns: A fibonacci backoff function.
  public static func fibonacci(_ duration: OperationDuration) -> Self {
    Self("Fibonacci every \(duration)") { duration * OperationCore.fibonacci($0) }
  }
}

// MARK: - Jittered

extension OperationBackoffFunction {
  /// Adds a jitter to this backoff function.
  ///
  /// Using a jitter will randomize the backoff value that is returned from the function in the
  /// range [0, x] where x is the value returned by this backoff function. This ensures that many
  /// concurrent operation runs do not overload any external services they utilize.
  ///
  /// - Parameter generator: A `RandomNumberGenerator` to use for computing jitter values.
  /// - Returns: This backoff function with jitter applied.
  public func jittered<T: RandomNumberGenerator & Sendable>(
    using generator: T = SystemRandomNumberGenerator()
  ) -> Self {
    let generator = LockedBox(value: generator)
    return Self("\(self.rawDescription) with jitter") { attempt in
      generator.inner.withLock { .random(in: (.zero)..<self(attempt), using: &$0) }
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
  /// - Returns: An ``OperationDuration`` for how long a query should wait before the next attempt.
  public func callAsFunction(_ attempt: Int) -> OperationDuration {
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

// MARK: - OperationModifier

extension OperationRequest {
  /// Sets the ``OperationBackoffFunction`` to use for this operation.
  ///
  /// - Parameter function: The ``OperationBackoffFunction`` to use.
  /// - Returns: A ``ModifiedOperation``.
  public func backoff(
    _ function: OperationBackoffFunction
  ) -> ModifiedOperation<Self, _OperationBackoffFunctionModifier<Self>> {
    self.modifier(_OperationBackoffFunctionModifier(function: function))
  }
}

public struct _OperationBackoffFunctionModifier<
  Operation: OperationRequest
>: _ContextUpdatingOperationModifier {
  let function: OperationBackoffFunction

  public func setup(context: inout OperationContext) {
    context.operationBackoffFunction = self.function
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The current ``OperationBackoffFunction`` in this context.
  ///
  /// The default value is ``OperationBackoffFunction/exponential(_:)`` with a base duration of 1
  /// second.
  public var operationBackoffFunction: OperationBackoffFunction {
    get { self[OperationBackoffFunctionKey.self] }
    set { self[OperationBackoffFunctionKey.self] = newValue }
  }

  private enum OperationBackoffFunctionKey: Key {
    static var defaultValue: OperationBackoffFunction { .exponential(.seconds(1)) }
  }
}
