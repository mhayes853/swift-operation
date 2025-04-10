import Foundation

// MARK: - QueryClock

public protocol QueryClock: Sendable {
  func now() -> Date
}

// MARK: - QueryClock

public struct SystemTimeClock: QueryClock {
  public func now() -> Date {
    Date()
  }
}

extension QueryClock where Self == SystemTimeClock {
  public static var systemTime: Self {
    SystemTimeClock()
  }
}

// MARK: - CustomQueryClock

public struct CustomQueryClock: QueryClock {
  let _now: @Sendable () -> Date

  public func now() -> Date {
    self._now()
  }
}

extension QueryClock where Self == CustomQueryClock {
  public static func custom(_ now: @escaping @Sendable () -> Date) -> Self {
    CustomQueryClock(_now: now)
  }
}

// MARK: - TimeFreezeClock

public struct TimeFreezeClock: QueryClock {
  @usableFromInline
  let date: Date

  @inlinable
  public func now() -> Date {
    self.date
  }
}

extension QueryClock where Self == TimeFreezeClock {
  public static var timeFreeze: Self {
    TimeFreezeClock(date: Date())
  }

  public static func timeFreeze(_ date: Date) -> Self {
    TimeFreezeClock(date: date)
  }
}

extension QueryClock {
  public func frozen() -> TimeFreezeClock {
    .timeFreeze(self.now())
  }
}

// MARK: - QueryContext

extension QueryContext {
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
