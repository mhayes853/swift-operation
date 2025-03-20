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
    Self { TimeInterval(Self.fibonacci(n: $0)) * base }
  }

  private static func fibonacci(n: Int) -> Int {
    guard n > 0 else { return 0 }
    let baseMatrix = Matrix2x2(a: 1, b: 1, c: 1, d: 0)
    return baseMatrix.power(exponent: n - 1).a
  }

  private struct Matrix2x2: Sendable {
    var a: Int
    var b: Int
    var c: Int
    var d: Int

    static let identity = Matrix2x2(a: 1, b: 0, c: 0, d: 1)

    func multiplied(by other: Self) -> Self {
      Self(
        a: a &* other.a &+ b &* other.c,
        b: a &* other.b &+ b &* other.d,
        c: c &* other.a &+ d &* other.c,
        d: c &* other.b &+ d &* other.d
      )
    }

    func power(exponent: Int) -> Self {
      var result = Self.identity
      var base = self
      var exp = exponent
      while exp > 0 {
        if !exp.isMultiple(of: 2) {
          result = result.multiplied(by: base)
        }
        base = base.multiplied(by: base)
        exp /= 2
      }
      return result
    }
  }
}

// MARK: - Jittered

extension QueryBackoffFunction {
  public func jittered<T: RandomNumberGenerator & Sendable>(using generator: T) -> Self {
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
    static var defaultValue: QueryBackoffFunction { .exponential(1) }
  }
}
