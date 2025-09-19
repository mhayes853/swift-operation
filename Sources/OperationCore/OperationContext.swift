// MARK: - OperationContext

/// An extensible collection of values that are accessible by operations.
///
/// `OperationContext` is a rough equivalent of SwiftUI's `EnvironmentValues` for an operation.
/// Similarly to `EnvironmentValues`, you can extend the context by adding a custom context
/// property using the ``Key`` protocol.
///
/// ```swift
/// extension OperationContext {
///   var myProperty: String {
///     get { self[MyPropertyKey.self] }
///     set { self[MyPropertyKey.self] = newValue }
///   }
///
///   private enum MyPropertyKey: Key {
///     static let defaultValue = "test"
///   }
/// }
/// ```
///
/// The context is accessible from many types in the library, including on ``OperationStore``
/// instances, within ``OperationRequest/run(isolation:in:with:)``, ``OperationTask``, and much
/// more.
///
/// See <doc:UtilizingOperationContext> to learn about best practicies when utilizing the context.
public struct OperationContext: Sendable {
  private var storage = [StorageKey: any Sendable]()

  /// Creates an empty context.
  ///
  /// You typically want to avoid creating a context from scratch. Doing so would only provide
  /// access to the default values for each property.
  public init() {}
}

// MARK: - Storage

extension OperationContext {
  private struct StorageKey: Hashable {
    let type: Any.Type

    var typeName: String {
      OperationCore.typeName(self.type)
    }

    static func == (lhs: StorageKey, rhs: StorageKey) -> Bool {
      lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self.type))
    }
  }
}

// MARK: - OperationContextKey

extension OperationContext {
  /// A protocol that defines the key for a custom context property.
  ///
  /// Similarly to SwiftUI's `EnvironmentValues`, you can extend the context by adding a custom
  /// context property.
  ///
  /// ```swift
  /// extension OperationContext {
  ///   var myProperty: String {
  ///     get { self[MyPropertyKey.self] }
  ///     set { self[MyPropertyKey.self] = newValue }
  ///   }
  ///
  ///   private enum MyPropertyKey: Key {
  ///     static let defaultValue = "test"
  ///   }
  /// }
  /// ```
  ///
  /// See <doc:UtilizingOperationContext> to learn about best practicies around custom context properties.
  public protocol Key<Value> {
    associatedtype Value: Sendable

    /// The default value for the context key.
    static var defaultValue: Value { get }
  }
}

// MARK: - Subscript

extension OperationContext {
  /// Accesses the context value with the specified key.
  ///
  /// Typically, you only use this subscript when defining a computed property for a custom
  /// context property. Similarly to SwiftUI's `EnvironmentValues`, you can extend the context by
  /// adding a custom context property using the ``Key`` protocol.
  ///
  /// ```swift
  /// extension OperationContext {
  ///   var myProperty: String {
  ///     get { self[MyPropertyKey.self] }
  ///     set { self[MyPropertyKey.self] = newValue }
  ///   }
  ///
  ///   private enum MyPropertyKey: Key {
  ///     static let defaultValue = "test"
  ///   }
  /// }
  /// ```
  ///
  /// See <doc:UtilizingOperationContext> to learn about best practicies around custom context properties.
  public subscript<Value>(_ key: (some Key<Value>).Type) -> Value {
    get { (self.storage[StorageKey(type: key)] as? Value) ?? key.defaultValue }
    set { self.storage[StorageKey(type: key)] = newValue }
  }
}

// MARK: - CustomStringConvertible

extension OperationContext: CustomStringConvertible {
  public var description: String {
    let string = self.storage.map { (key, value) in "\(key.typeName) = \(value)" }
      .joined(separator: ", ")
    return "[\(string)]"
  }
}
