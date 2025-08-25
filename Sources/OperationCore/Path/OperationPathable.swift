/// A protocol that represents a value that has an associated ``OperationPath``.
public protocol OperationPathable {
  /// The associated ``OperationPath`` for this value.
  var path: OperationPath { get }
}
