// MARK: - Box

final class Box<Value: Sendable>: Sendable {
  let value: Value

  init(value: Value) {
    self.value = value
  }
}

// MARK: - WeakBox

final class WeakBox<Value: AnyObject> {
  weak var value: Value?

  init(value: Value?) {
    self.value = value
  }
}

// MARK: - LockedWeakBox

final class LockedWeakBox<Value: AnyObject>: Sendable {
  let inner: Lock<WeakBox<Value>>

  init(value: sending Value?) {
    self.inner = Lock(WeakBox(value: value))
  }
}

// MARK: - LockedBox

final class LockedBox<Value>: Sendable {
  let inner: Lock<Value>

  init(value: sending Value) {
    self.inner = Lock(value)
  }
}
