/// A protocol that represents a value that has an associated ``QueryPath``.
public protocol QueryPathable {
  /// The associated ``QueryPath`` fot this value.
  var path: QueryPath { get }
}
