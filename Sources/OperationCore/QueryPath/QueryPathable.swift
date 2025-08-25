/// A protocol that represents a value that has an associated ``QueryPath``.
public protocol QueryPathable {
  /// The associated ``QueryPath`` for this value.
  var path: QueryPath { get }
}
