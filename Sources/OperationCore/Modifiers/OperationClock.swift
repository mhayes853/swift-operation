import Foundation

// MARK: - OperationClock

/// A protocol for controlling the current date in queries.
///
/// You can override the ``OperationContext/queryClock`` context value to control the values of
/// ``OperationState/valueLastUpdatedAt`` and ``OperationState/errorLastUpdatedAt``
/// whenever your query yields a result.
public protocol OperationClock: Sendable {
  /// Returns the current date according to the clock.
  func now() -> Date
}

// MARK: - OperationClock

/// A ``OperationClock`` that returns the system's current time.
public struct SystemTimeClock: OperationClock {
  public func now() -> Date {
    Date()
  }
}

extension OperationClock where Self == SystemTimeClock {
  /// A ``OperationClock`` that returns the system's current time.
  public static var systemTime: Self {
    SystemTimeClock()
  }
}

// MARK: - CustomOperationClock

/// A ``OperationClock`` that returns the current date based on a specified closure.
public struct CustomOperationClock: OperationClock {
  let _now: @Sendable () -> Date

  public func now() -> Date {
    self._now()
  }
}

extension OperationClock where Self == CustomOperationClock {
  /// A ``OperationClock`` that returns the current date based on the return value of `now`.
  ///
  /// - Parameter now: A closure to compute the current date.
  /// - Returns: A ``CustomOperationClock``.
  public static func custom(_ now: @escaping @Sendable () -> Date) -> Self {
    CustomOperationClock(_now: now)
  }
}

// MARK: - TimeFreezeClock

/// A ``OperationClock`` that returns a constant date.
public struct TimeFreezeClock: OperationClock {
  @usableFromInline
  let date: Date

  @inlinable
  public func now() -> Date {
    self.date
  }
}

extension OperationClock where Self == TimeFreezeClock {
  /// A ``OperationClock`` that computes the current date upon creation, and always returns that date.
  public static var timeFreeze: Self {
    TimeFreezeClock(date: Date())
  }

  /// A ``OperationClock`` that always returns the provided `date`.
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

// MARK: - QueryModifier

extension QueryRequest {
  /// The ``OperationClock`` to use for this query.
  ///
  /// - Parameter clock: A ``OperationClock``.
  /// - Returns: A ``ModifiedQuery``.
  public func clock<C>(_ clock: C) -> ModifiedQuery<Self, _OperationClockModifier<Self, C>> {
    self.modifier(_OperationClockModifier(clock: clock))
  }
}

public struct _OperationClockModifier<
  Query: QueryRequest,
  C: OperationClock
>: _ContextUpdatingQueryModifier {
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
  public var operationClock: any OperationClock {
    get { self[OperationClockKey.self] }
    set { self[OperationClockKey.self] = newValue }
  }

  private struct OperationClockKey: Key {
    static var defaultValue: any OperationClock {
      .systemTime
    }
  }
}
