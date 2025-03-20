import Foundation

// MARK: - QueryBackoffFunction

public struct QueryBackoffFunction: Sendable {
  private let backoff: @Sendable (Int) -> TimeInterval

  public init(_ backoff: @escaping @Sendable (Int) -> TimeInterval) {
    self.backoff = backoff
  }
}

// MARK: - Constant

extension QueryBackoffFunction {
  public static let noBackoff = Self.constant(0)

  public static func constant(_ interval: TimeInterval) -> Self {
    Self { _ in interval }
  }
}

// MARK: - Exponential

extension QueryBackoffFunction {
  public static func exponential(_ base: TimeInterval) -> Self {
    Self { $0 == 0 ? 0 : base * pow(2, TimeInterval($0 - 1)) }
  }
}

// MARK: - Linear

extension QueryBackoffFunction {
  public static func linear(_ base: TimeInterval) -> Self {
    Self { TimeInterval($0) * base }
  }
}

// MARK: - Fibonacci

extension QueryBackoffFunction {
  public static func fibonacci(_ base: TimeInterval) -> Self {
    Self { TimeInterval(QueryCore.fibonacci($0)) * base }
  }
}

// MARK: - Jittered

extension QueryBackoffFunction {
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
  public func callAsFunction(_ attempt: Int) -> TimeInterval {
    backoff(attempt)
  }
}

// MARK: - QueryContext

extension QueryContext {
  public var queryBackoffFunction: QueryBackoffFunction {
    get { self[QueryBackoffFunctionKey.self] }
    set { self[QueryBackoffFunctionKey.self] = newValue }
  }

  private enum QueryBackoffFunctionKey: Key {
    static var defaultValue: QueryBackoffFunction { .fibonacci(1) }
  }
}
