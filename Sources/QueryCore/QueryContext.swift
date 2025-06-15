// MARK: - QueryContext

/// An extensible collection of values that are accessible by your queries.
///
/// `QueryContext` is a rough equivalent of SwiftUI's `EnvironmentValues` for your queries.
/// Similarly to `EnvironmentValues`, you can extend the context by adding a custom context
/// property using the ``Key`` protocol.
///
/// ```swift
/// extension QueryContext {
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
/// A context is handed to your query through ``QueryRequest/fetch(in:with:)``, however you can
/// modify any properties on that context before it gets passed to your query via
/// ``QueryRequest/setup(context:)`` or ``QueryStore/context`` (on a ``QueryStore`` instance).
///
/// See <doc:UtilizingQueryContext> to learn about best practicies when utilizing the context.
public struct QueryContext: Sendable {
  private var storage = [StorageKey: any Sendable]()

  /// Creates an empty context.
  ///
  /// You typically want to avoid creating a context from scratch. Doing so would only provide
  /// access to the default values for each property.
  public init() {}
}

// MARK: - Storage

extension QueryContext {
  private struct StorageKey: Hashable {
    let id: ObjectIdentifier
    let typeName: String

    init(type: Any.Type) {
      self.id = ObjectIdentifier(type)
      self.typeName = QueryCore.typeName(type)
    }
  }
}

// MARK: - QueryContextKey

extension QueryContext {
  /// A protocol that defines the key for a custom context property.
  ///
  /// Similarly to SwiftUI's `EnvironmentValues`, you can extend the context by adding a custom
  /// context property.
  ///
  /// ```swift
  /// extension QueryContext {
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
  /// See <doc:UtilizingQueryContext> to learn about best practicies around custom context properties.
  public protocol Key<Value> {
    associatedtype Value: Sendable

    /// The default value for the context key.
    static var defaultValue: Value { get }
  }
}

// MARK: - Subscript

extension QueryContext {
  /// Accesses the context value with the specified key.
  ///
  /// Typically, you only use this subscript when defining a computed property for a custom
  /// context property. Similarly to SwiftUI's `EnvironmentValues`, you can extend the context by
  /// adding a custom context property using the ``Key`` protocol.
  ///
  /// ```swift
  /// extension QueryContext {
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
  /// See <doc:UtilizingQueryContext> to learn about best practicies around custom context properties.
  public subscript<Value>(_ key: (some Key<Value>).Type) -> Value {
    get { (self.storage[StorageKey(type: key)] as? Value) ?? key.defaultValue }
    set { self.storage[StorageKey(type: key)] = newValue }
  }
}

// MARK: - CustomStringConvertible

extension QueryContext: CustomStringConvertible {
  public var description: String {
    let string = self.storage.map { (key, value) in "\(key.typeName) = \(value)" }
      .joined(separator: ", ")
    return "[\(string)]"
  }
}
