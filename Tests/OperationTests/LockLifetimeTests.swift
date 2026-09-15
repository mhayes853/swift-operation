import CustomDump
import Operation
import Testing

@Test("Lock Releases Its Stored Value")
func lockReleasesItsStoredValue() {
  weak var value: LifetimeValue?
  do {
    let lock = Lock(LifetimeValue())
    value = lock.withLock { $0 }
    expectNoDifference(value == nil, false)
  }
  expectNoDifference(value == nil, true)
}

@Test("RecursiveLock Releases Its Stored Value")
func recursiveLockReleasesItsStoredValue() {
  weak var value: LifetimeValue?
  do {
    let lock = RecursiveLock(LifetimeValue())
    value = lock.withLock { $0 }
    expectNoDifference(value == nil, false)
  }
  expectNoDifference(value == nil, true)
}

private final class LifetimeValue: Sendable {}
