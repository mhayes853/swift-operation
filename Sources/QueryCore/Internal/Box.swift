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
