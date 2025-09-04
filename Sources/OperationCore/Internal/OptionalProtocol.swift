public protocol _OptionalProtocol {
  associatedtype Wrapped

  static func _from(wrapped: Wrapped?) -> Self

  var _wrapped: Wrapped? { get }
}

extension _OptionalProtocol {
  public func _orElse(unwrapped: @autoclosure () -> Wrapped) -> Wrapped {
    self._wrapped ?? unwrapped()
  }
}

extension Optional: _OptionalProtocol {
  public static func _from(wrapped: Wrapped?) -> Self {
    wrapped
  }

  public var _wrapped: Wrapped? { self }
}
