import Foundation

// MARK: - OperationDelayer

/// A protocol for artificially delaying queries.
///
/// Artificial delays are useful for adding backoff to query retries, avoiding rate limits, and
/// much more. You can override the ``OperationContext/operationDelayer`` context property to override the
/// delay mechanism for your queries.
public protocol OperationDelayer: Sendable {
  /// Delay for the specified number of seconds.
  ///
  /// - Parameter seconds: The number of seconds to delay for.
  func delay(for seconds: TimeInterval) async throws
}

// MARK: - Task Sleep Delayer

/// A ``OperationDelayer`` that uses a `Task.sleep` for delaying.
public struct TaskSleepDelayer: OperationDelayer {
  public func delay(for seconds: TimeInterval) async throws {
    try await Task.sleep(nanoseconds: UInt64(TimeInterval(NSEC_PER_SEC) * seconds))
  }
}

extension OperationDelayer where Self == TaskSleepDelayer {
  /// A ``OperationDelayer`` that uses a `Task.sleep` for delaying.
  public static var taskSleep: Self {
    TaskSleepDelayer()
  }
}

#if !canImport(Darwin)
  private let NSEC_PER_SEC: UInt64 = 1_000_000_000
#endif

// MARK: - Clock Delayer

/// A ``OperationDelayer`` that uses the `Clock` protocol to delay queries.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct ClockDelayer<C: Clock> where C.Duration == Duration {
  let clock: C
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension ClockDelayer: OperationDelayer {
  public func delay(for seconds: TimeInterval) async throws {
    try await clock.sleep(for: .seconds(seconds))
  }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension OperationDelayer {
  /// A ``OperationDelayer`` that uses the `Clock` protocol to delay queries.
  ///
  /// - Parameter clock: The `Clock` to use to perform delays.
  /// - Returns: A ``OperationDelayer``.
  public static func clock<C: Clock>(_ clock: C) -> Self where Self == ClockDelayer<C> {
    Self(clock: clock)
  }
}

// MARK: - NoDelayer

/// A ``OperationDelayer`` that performs no delays.
///
/// This is especially useful for testing, where having delays can slow down your test suite.
public struct NoDelayer: OperationDelayer {
  @inlinable
  public func delay(for seconds: TimeInterval) async throws {
    try Task.checkCancellation()
  }
}

extension OperationDelayer where Self == NoDelayer {
  /// A ``OperationDelayer`` that performs no delays.
  ///
  /// This is especially useful for testing, where having delays can slow down your test suite.
  public static var noDelay: Self { NoDelayer() }
}

// MARK: - AnyDelayer

/// A type-erased ``OperationDelayer``.
public struct AnyDelayer: OperationDelayer {
  public let base: any OperationDelayer

  /// Creates a type-erased ``OperationDelayer``.
  ///
  /// - Parameter base: The ``OperationDelayer`` to erase.
  public init(_ base: any OperationDelayer) {
    self.base = base
  }

  public func delay(for seconds: TimeInterval) async throws {
    try await self.base.delay(for: seconds)
  }
}

// MARK: - OperationModifier

extension OperationRequest {
  /// Sets the ``OperationDelayer`` to use for this query.
  ///
  /// - Parameter delayer: The ``OperationDelayer`` to use.
  /// - Returns: A ``ModifiedOperation``.
  public func delayer<Delayer>(
    _ delayer: Delayer
  ) -> ModifiedOperation<Self, _DelayerModifier<Self, Delayer>> {
    self.modifier(_DelayerModifier(delayer: delayer))
  }
}

public struct _DelayerModifier<
  Operation: OperationRequest,
  Delayer: OperationDelayer
>: _ContextUpdatingOperationModifier {
  let delayer: Delayer

  public func setup(context: inout OperationContext) {
    context.operationDelayer = self.delayer
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The current ``OperationDelayer`` in this context.
  ///
  /// The default value is platform dependent. On Darwin platforms,
  /// ``OperationDelayer/taskSleep`` is the default value, and ``OperationDelayer/clock(_:)`` is the
  /// default value on all other platforms.
  public var operationDelayer: any OperationDelayer {
    get { self[OperationDelayerKey.self] }
    set { self[OperationDelayerKey.self] = newValue }
  }

  private enum OperationDelayerKey: Key {
    static var defaultValue: any OperationDelayer {
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
