import CustomDump
import Operation
import Testing

@Suite
struct `Lock Lifetime tests` {
  @Test
  func `Lock Releases Its Stored Value`() {
    weak var value: LifetimeValue?
    do {
      let lock = Lock(LifetimeValue())
      value = lock.withLock { $0 }
      expectNoDifference(value == nil, false)
    }
    expectNoDifference(value == nil, true)
  }

  @Test
  func `RecursiveLock Releases Its Stored Value`() {
    weak var value: LifetimeValue?
    do {
      let lock = RecursiveLock(LifetimeValue())
      value = lock.withLock { $0 }
      expectNoDifference(value == nil, false)
    }
    expectNoDifference(value == nil, true)
  }
}

private final class LifetimeValue: Sendable {}
