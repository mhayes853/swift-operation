// MARK: - WeakBox

final class WeakBox<Value: AnyObject> {
  weak var value: Value?

  init(value: Value?) {
    self.value = value
  }
}

// MARK: - LockedWeakBox

final class LockedWeakBox<Value: AnyObject>: Sendable {
  let inner: RecursiveLock<WeakBox<Value>>

  init(value: sending Value?) {
    self.inner = RecursiveLock(WeakBox(value: value))
  }
}

// MARK: - LockedBox

final class LockedBox<Value>: Sendable {
  let inner: RecursiveLock<Value>

  init(value: sending Value) {
    self.inner = RecursiveLock(value)
  }
}
