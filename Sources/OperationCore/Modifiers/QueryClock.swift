import Foundation

// MARK: - QueryClock

/// A protocol for controlling the current date in queries.
///
/// You can override the ``QueryContext/queryClock`` context value to control the values of
/// ``QueryStateProtocol/valueLastUpdatedAt`` and ``QueryStateProtocol/errorLastUpdatedAt``
/// whenever your query yields a result.
public protocol QueryClock: Sendable {
  /// Returns the current date according to the clock.
  func now() -> Date
}

// MARK: - QueryClock

/// A ``QueryClock`` that returns the system's current time.
public struct SystemTimeClock: QueryClock {
  public func now() -> Date {
    Date()
  }
}

extension QueryClock where Self == SystemTimeClock {
  /// A ``QueryClock`` that returns the system's current time.
  public static var systemTime: Self {
    SystemTimeClock()
  }
}

// MARK: - CustomQueryClock

/// A ``QueryClock`` that returns the current date based on a specified closure.
public struct CustomQueryClock: QueryClock {
  let _now: @Sendable () -> Date

  public func now() -> Date {
    self._now()
  }
}

extension QueryClock where Self == CustomQueryClock {
  /// A ``QueryClock`` that returns the current date based on the return value of `now`.
  ///
  /// - Parameter now: A closure to compute the current date.
  /// - Returns: A ``CustomQueryClock``.
  public static func custom(_ now: @escaping @Sendable () -> Date) -> Self {
    CustomQueryClock(_now: now)
  }
}

// MARK: - TimeFreezeClock

/// A ``QueryClock`` that returns a constant date.
public struct TimeFreezeClock: QueryClock {
  @usableFromInline
  let date: Date

  @inlinable
  public func now() -> Date {
    self.date
  }
}

extension QueryClock where Self == TimeFreezeClock {
  /// A ``QueryClock`` that computes the current date upon creation, and always returns that date.
  public static var timeFreeze: Self {
    TimeFreezeClock(date: Date())
  }

  /// A ``QueryClock`` that always returns the provided `date`.
  ///
  /// - Parameter date: The date to return.
  /// - Returns: A ``TimeFreezeClock``.
  public static func timeFreeze(_ date: Date) -> Self {
    TimeFreezeClock(date: date)
  }
}

extension QueryClock {
  /// Freezes this clock.
  ///
  /// - Returns: A ``TimeFreezeClock`` based on this clock's ``now()`` return value.
  public func frozen() -> TimeFreezeClock {
    .timeFreeze(self.now())
  }
}

// MARK: - QueryModifier

extension QueryRequest {
  /// The ``QueryClock`` to use for this query.
  ///
  /// - Parameter clock: A ``QueryClock``.
  /// - Returns: A ``ModifiedQuery``.
  public func clock<C>(_ clock: C) -> ModifiedQuery<Self, _QueryClockModifier<Self, C>> {
    self.modifier(_QueryClockModifier(clock: clock))
  }
}

public struct _QueryClockModifier<
  Query: QueryRequest,
  C: QueryClock
>: _ContextUpdatingQueryModifier {
  let clock: C

  public func setup(context: inout QueryContext) {
    context.queryClock = self.clock
  }
}

// MARK: - QueryContext

extension QueryContext {
  /// The current ``QueryClock`` in this context.
  ///
  /// The default value is ``QueryClock/systemTime``.
  public var queryClock: any QueryClock {
    get { self[QueryClockKey.self] }
    set { self[QueryClockKey.self] = newValue }
  }

  private struct QueryClockKey: Key {
    static var defaultValue: any QueryClock {
      .systemTime
    }
  }
}
