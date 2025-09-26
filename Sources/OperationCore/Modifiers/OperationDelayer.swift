import Foundation

// MARK: - OperationDelayer

/// A protocol for artificially delaying operations.
///
/// Artificial delays are useful for adding backoff to operation retries, avoiding rate limits, and
/// much more. You can use the ``OperationRequest/delayer(_:)`` modifier to override the delayer
/// for an operation.
public protocol OperationDelayer {
  /// Delay for the specified ``OperationDuration``.
  ///
  /// - Parameter duration: The duration to delay for.
  func delay(for duration: OperationDuration) async throws
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension OperationDelayer {
  /// Delay for the specified `OperationDuration`.
  ///
  /// - Parameter duration: The duration to delay for.
  public func delay(for duration: Duration) async throws {
    try await self.delay(for: OperationDuration(duration: duration))
  }
}

// MARK: - Task Sleep Delayer

/// An ``OperationDelayer`` that uses a `Task.sleep` for delaying.
public struct TaskSleepDelayer: OperationDelayer, Sendable {
  public init() {}

  public func delay(for duration: OperationDuration) async throws {
    try await Task.sleep(nanoseconds: UInt64(duration.secondsDouble * nanosecondsPerSecond))
  }
}

extension OperationDelayer where Self == TaskSleepDelayer {
  /// An ``OperationDelayer`` that uses a `Task.sleep` for delaying.
  public static var taskSleep: Self {
    TaskSleepDelayer()
  }
}

private let nanosecondsPerSecond = Double(1_000_000_000)

// MARK: - Clock Delayer

/// An ``OperationDelayer`` that uses the `Clock` protocol to delay operations.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct ClockDelayer<C: Clock>: OperationDelayer, Sendable where C.Duration == Duration {
  private let clock: C

  public init(_ clock: C) {
    self.clock = clock
  }

  public func delay(for duration: OperationDuration) async throws {
    try await clock.sleep(for: Duration(duration: duration))
  }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension OperationDelayer {
  /// An ``OperationDelayer`` that uses the `Clock` protocol to delay operations.
  ///
  /// - Parameter clock: The `Clock` to use to perform delays.
  /// - Returns: A ``ClockDelayer``.
  public static func clock<C: Clock>(_ clock: C) -> Self where Self == ClockDelayer<C> {
    Self(clock)
  }
}

// MARK: - NoDelayer

/// an ``OperationDelayer`` that performs no delays.
///
/// This is especially useful for testing, where having delays can slow down your test suite.
public struct NoDelayer: OperationDelayer, Sendable {
  public init() {}

  public func delay(for duration: OperationDuration) async throws {
    try Task.checkCancellation()
  }
}

extension OperationDelayer where Self == NoDelayer {
  /// an ``OperationDelayer`` that performs no delays.
  ///
  /// This is especially useful for testing, where having delays can slow down your test suite.
  public static var noDelay: Self { NoDelayer() }
}

// MARK: - AnyDelayer

/// A type-erased ``OperationDelayer``.
public struct AnySendableDelayer: OperationDelayer, Sendable {
  public let base: any OperationDelayer & Sendable

  /// Creates a type-erased ``OperationDelayer``.
  ///
  /// - Parameter base: The ``OperationDelayer`` to erase.
  public init(_ base: any OperationDelayer & Sendable) {
    self.base = base
  }

  public func delay(for duration: OperationDuration) async throws {
    try await self.base.delay(for: duration)
  }
}

// MARK: - OperationModifier

extension OperationRequest {
  /// Sets the ``OperationDelayer`` to use for this operation.
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
  Delayer: OperationDelayer & Sendable
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
  /// The default value is platform dependent. If ``OperationDelayer/clock(_:)`` is available on
  /// the current platform, then it is used. Otherwise, the default value falls back to
  /// ``OperationDelayer/taskSleep``.
  public var operationDelayer: any OperationDelayer & Sendable {
    get { self[OperationDelayerKey.self] }
    set { self[OperationDelayerKey.self] = newValue }
  }

  private enum OperationDelayerKey: Key {
    static var defaultValue: any OperationDelayer & Sendable {
      #if canImport(Darwin)
        if #available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *) {
          ClockDelayer(ContinuousClock())
        } else {
          TaskSleepDelayer()
        }
      #else
        ClockDelayer(ContinuousClock())
      #endif
    }
  }
}
