import Foundation

// MARK: - QueryDelayer

/// A protocol for artificially delaying queries.
///
/// Artificial delays are useful for adding backoff to query retries, avoiding rate limits, and
/// much more. You can override the ``QueryContext/queryDelayer`` context property to override the
/// delay mechanism for your queries.
public protocol QueryDelayer: Sendable {
  /// Delay for the specified number of seconds.
  ///
  /// - Parameter seconds: The number of seconds to delay for.
  func delay(for seconds: TimeInterval) async throws
}

// MARK: - Task Sleep Delayer

/// A ``QueryDelayer`` that uses a `Task.sleep` for delaying.
public struct TaskSleepDelayer: QueryDelayer {
  public func delay(for seconds: TimeInterval) async throws {
    try await Task.sleep(nanoseconds: UInt64(TimeInterval(NSEC_PER_SEC) * seconds))
  }
}

extension QueryDelayer where Self == TaskSleepDelayer {
  /// A ``QueryDelayer`` that uses a `Task.sleep` for delaying.
  public static var taskSleep: Self {
    TaskSleepDelayer()
  }
}

#if !canImport(Darwin)
  private let NSEC_PER_SEC: UInt64 = 1_000_000_000
#endif

// MARK: - Clock Delayer

/// A ``QueryDelayer`` that uses the `Clock` protocol to delay queries.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct ClockDelayer<C: Clock> where C.Duration == Duration {
  let clock: C
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension ClockDelayer: QueryDelayer {
  public func delay(for seconds: TimeInterval) async throws {
    try await clock.sleep(for: .seconds(seconds))
  }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension QueryDelayer {
  /// A ``QueryDelayer`` that uses the `Clock` protocol to delay queries.
  ///
  /// - Parameter clock: The `Clock` to use to perform delays.
  /// - Returns: A ``ClockDelayer``.
  public static func clock<C: Clock>(_ clock: C) -> Self where Self == ClockDelayer<C> {
    Self(clock: clock)
  }
}

// MARK: - NoDelayer

/// A ``QueryDelayer`` that performs no delays.
///
/// This is especially useful for testing, where having delays can slow down your test suite.
public struct NoDelayer: QueryDelayer {
  @inlinable
  public func delay(for seconds: TimeInterval) async throws {
    try Task.checkCancellation()
  }
}

extension QueryDelayer where Self == NoDelayer {
  /// A ``QueryDelayer`` that performs no delays.
  ///
  /// This is especially useful for testing, where having delays can slow down your test suite.
  public static var noDelay: Self { NoDelayer() }
}

// MARK: - AnyDelayer

/// A type-erased ``QueryDelayer``.
public struct AnyDelayer: QueryDelayer {
  public let base: any QueryDelayer

  /// Creates a type-erased ``QueryDelayer``.
  ///
  /// - Parameter base: The ``QueryDelayer`` to erase.
  public init(_ base: any QueryDelayer) {
    self.base = base
  }

  public func delay(for seconds: TimeInterval) async throws {
    try await self.base.delay(for: seconds)
  }
}

// MARK: - QueryModifier

extension QueryRequest {
  /// Sets the ``QueryDelayer`` to use for this query.
  ///
  /// - Parameter delayer: The ``QueryDelayer`` to use.
  /// - Returns: A ``ModifiedQuery``.
  public func delayer<Delayer>(
    _ delayer: Delayer
  ) -> ModifiedQuery<Self, _DelayerModifier<Self, Delayer>> {
    self.modifier(_DelayerModifier(delayer: delayer))
  }
}

public struct _DelayerModifier<
  Query: QueryRequest,
  Delayer: QueryDelayer
>: _ContextUpdatingQueryModifier {
  let delayer: Delayer

  public func setup(context: inout QueryContext) {
    context.queryDelayer = self.delayer
  }
}

// MARK: - QueryContext

extension QueryContext {
  /// The current ``QueryDelayer`` in this context.
  ///
  /// The default value is platform dependent. On Darwin platforms,
  /// ``QueryDelayer/taskSleep`` is the default value, and ``QueryDelayer/clock(_:)`` is the
  /// default value on all other platforms.
  public var queryDelayer: any QueryDelayer {
    get { self[QueryDelayerKey.self] }
    set { self[QueryDelayerKey.self] = newValue }
  }

  private enum QueryDelayerKey: Key {
    static var defaultValue: any QueryDelayer {
      #if canImport(Darwin)
        if #available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *) {
          .clock(ContinuousClock())
        } else {
          .taskSleep
        }
      #else
        .clock(ContinuousClock())
      #endif
    }
  }
}
