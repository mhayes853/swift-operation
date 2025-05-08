// MARK: - QueryPath

/// A data type that uniquely identifies a ``QueryRequest``.
///
/// You can opt to manually implement ``QueryRequest/path-1limj`` when your query does not conform
/// to Hashable or Identifiable like so.
///
/// ```swift
/// struct UserByNameQuery: QueryRequest {
///   let name: String
///
///   var path: QueryPath {
///     ["user", name]
///   }
///
///   // ...
/// }
/// ```
///
/// If you have multiple views using `UserByNameQuery`, you can access all instances of the query
/// state for those views by pattern matching with a ``QueryClient``.
///
/// ```swift
/// // Retrieves all QueryStore instances for every UserByNameQuery
/// // in the app.
/// let stores = client.stores(
///   matching: ["user"],
///   as: UserByNameQuery.State.self
/// )
/// ```
///
/// > Note: See <doc:PatternMatchingAndStateManagement> to learn best practicies for managing your
/// > global application state using `QueryPath`.
public struct QueryPath: Hashable, Sendable {
  private let elements: [AnyHashableSendable]
  
  /// Creates a path from an array of Hashable and Sendable elements.
  ///
  /// - Parameter elements: The elements that make up this path.
  public init(_ elements: [any Hashable & Sendable] = []) {
    self.elements = elements.map(AnyHashableSendable.init)
  }
}

// MARK: - Matches

extension QueryPath {
  /// Returns true when this path is the prefix of another path.
  ///
  /// - Parameter other: The path to match against.
  /// - Returns: True if this path is a prefix of `other`.
  public func isPrefix(of other: Self) -> Bool {
    guard self.elements.count <= other.elements.count else { return false }
    return (0..<min(self.elements.count, other.elements.count))
      .allSatisfy { i in self.elements[i] == other.elements[i] }
  }
}

// MARK: - ExpressibleByArrayLiteral

extension QueryPath: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: (any Hashable & Sendable)...) {
    self.init(elements)
  }
}

// MARK: - CustomStringConvertible

extension QueryPath: CustomStringConvertible {
  public var description: String {
    "QueryPath([\(elements.map { self.elementDescription($0) }.joined(separator: ", "))])"
  }

  private func elementDescription(_ element: AnyHashableSendable) -> String {
    if element.base is any StringProtocol {
      return "\"\(element.description)\""
    }
    return element.description
  }
}
