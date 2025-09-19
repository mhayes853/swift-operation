import Foundation

// MARK: - OperationClock

/// A protocol for controlling the current date in operations.
///
/// You can override the ``OperationContext/operationClock`` context value to control the values of
/// ``OperationState/valueLastUpdatedAt`` and ``OperationState/errorLastUpdatedAt``
/// whenever an operation yields a result.
public protocol OperationClock {
  /// Returns the current date according to the clock.
  func now() -> Date
}

// MARK: - OperationClock

/// An ``OperationClock`` that returns the system's current time.
public struct SystemTimeClock: OperationClock, Sendable {
  public init() {}

  public func now() -> Date {
    Date()
  }
}

extension OperationClock where Self == SystemTimeClock {
  /// An ``OperationClock`` that returns the system's current time.
  public static var systemTime: Self {
    SystemTimeClock()
  }
}

// MARK: - CustomOperationClock

/// An ``OperationClock`` that returns the current date based on a specified closure.
public struct CustomOperationClock: OperationClock, Sendable {
  private let _now: @Sendable () -> Date

  public init(_ now: @escaping @Sendable () -> Date) {
    self._now = now
  }

  public func now() -> Date {
    self._now()
  }
}

extension OperationClock where Self == CustomOperationClock {
  /// An ``OperationClock`` that returns the current date based on the return value of `now`.
  ///
  /// - Parameter now: A closure to compute the current date.
  /// - Returns: A ``CustomOperationClock``.
  public static func custom(_ now: @escaping @Sendable () -> Date) -> Self {
    CustomOperationClock(now)
  }
}

// MARK: - TimeFreezeClock

/// A n``OperationClock`` that returns a constant date.
public struct TimeFreezeClock: OperationClock, Sendable {
  @usableFromInline
  let date: Date

  public init(date: Date) {
    self.date = date
  }

  @inlinable
  public func now() -> Date {
    self.date
  }
}

extension OperationClock where Self == TimeFreezeClock {
  /// An ``OperationClock`` that computes the current date upon creation, and always returns that date.
  public static var timeFreeze: Self {
    TimeFreezeClock(date: Date())
  }

  /// An ``OperationClock`` that always returns the provided `date`.
  ///
  /// - Parameter date: The date to return.
  /// - Returns: A ``TimeFreezeClock``.
  public static func timeFreeze(_ date: Date) -> Self {
    TimeFreezeClock(date: date)
  }
}

extension OperationClock {
  /// Freezes this clock.
  ///
  /// - Returns: A ``TimeFreezeClock`` based on this clock's ``now()`` return value.
  public func frozen() -> TimeFreezeClock {
    .timeFreeze(self.now())
  }
}

// MARK: - OperationModifier

extension OperationRequest {
  /// The ``OperationClock`` to use for this operation.
  ///
  /// - Parameter clock: A ``OperationClock``.
  /// - Returns: A ``ModifiedOperation``.
  public func clock<C>(_ clock: C) -> ModifiedOperation<Self, _OperationClockModifier<Self, C>> {
    self.modifier(_OperationClockModifier(clock: clock))
  }
}

public struct _OperationClockModifier<
  Operation: OperationRequest,
  C: OperationClock & Sendable
>: _ContextUpdatingOperationModifier {
  let clock: C

  public func setup(context: inout OperationContext) {
    context.operationClock = self.clock
  }
}

// MARK: - OperationContext

extension OperationContext {
  /// The current ``OperationClock`` in this context.
  ///
  /// The default value is ``OperationClock/systemTime``.
  public var operationClock: any OperationClock & Sendable {
    get { self[OperationClockKey.self] }
    set { self[OperationClockKey.self] = newValue }
  }

  private struct OperationClockKey: Key {
    static var defaultValue: any OperationClock & Sendable {
      SystemTimeClock()
    }
  }
}
