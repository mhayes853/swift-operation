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
  private var storage: Storage

  /// Creates a path from an array of Hashable and Sendable elements.
  ///
  /// - Parameter elements: The elements that make up this path.
  public init(_ elements: [any Hashable & Sendable]) {
    self.storage = .array(elements.map(AnyHashableSendable.init))
  }

  /// Creates an empty path.
  public init() {
    self.storage = .empty
  }
}

// MARK: - Single Element Init

extension QueryPath {
  /// Creates a path from a single element.
  ///
  /// - Parameter element: The sole element that makes up this path.
  public init(_ element: some Hashable & Sendable) {
    self.storage = .single(AnyHashableSendable(element))
  }
}

// MARK: - Matches

extension QueryPath {
  /// Returns true when this path is the prefix of another path.
  ///
  /// - Parameter other: The path to match against.
  /// - Returns: True if this path is a prefix of `other`.
  public func isPrefix(of other: Self) -> Bool {
    switch (self.storage, other.storage) {
    case (.empty, _), (.array([]), _):
      return true
    case let (.single(e1), .single(e2)):
      return e1 == e2
    case let (.single(e1), .array(e2)):
      return e1 == e2.first
    case let (.array(e1), .single(e2)):
      return e1.count == 1 && e1.first == e2
    case let (.array(e1), .array(e2)):
      guard e1.count <= e2.count else { return false }
      return (0..<min(e1.count, e2.count)).allSatisfy { i in e1[i] == e2[i] }
    default:
      return false
    }
  }
}

// MARK: - Appending

extension QueryPath {
  /// Appends the contents of `other` to this path.
  ///
  /// - Parameter other: Another path.
  public mutating func append(_ other: QueryPath) {
    switch (self.storage, other.storage) {
    case (.single, .empty), (.single, .array([])), (.array, .empty), (.array, .array([])):
      break
    case (.array([]), _), (.empty, _):
      self.storage = other.storage
    case let (.single(e1), .single(e2)):
      self.storage = .array([e1, e2])
    case let (.single(e1), .array(e2)):
      self.storage = .array([e1] + e2)
    case let (.array(e1), .single(e2)):
      self.storage = .array(e1 + [e2])
    case let (.array(e1), .array(e2)):
      self.storage = .array(e1 + e2)
    }
  }

  /// Appends `element` to this path.
  ///
  /// - Parameter element: The element to append.
  public mutating func append(_ element: (some Hashable & Sendable)) {
    self.append(QueryPath(element))
  }

  /// Returns a new path with the contents of this path appended with the contents of `other`.
  ///
  /// - Parameter other: Another path.
  /// - Returns: A new path with the contents of this path appended with the contents of `other`.
  public func appending(_ other: QueryPath) -> Self {
    var new = self
    new.append(other)
    return new
  }

  /// Returns a new path with `element` appended to this path.
  ///
  /// - Parameter element: The element to append.
  /// - Returns: A new path with `element` appended to this path.
  public func appending(_ element: (some Hashable & Sendable)) -> Self {
    var new = self
    new.append(element)
    return new
  }
}

// MARK: - Storage

extension QueryPath {
  private enum Storage: Hashable, Sendable {
    case empty
    case single(AnyHashableSendable)
    case array([AnyHashableSendable])

    var elements: any RandomAccessCollection<AnyHashableSendable> {
      switch self {
      case .empty: EmptyCollection()
      case let .single(element): CollectionOfOne(element)
      case let .array(elements): elements
      }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case (.empty, .empty), (.empty, .array([])), (.array([]), .empty):
        return true
      case let (.single(e1), .single(e2)):
        return e1 == e2
      case let (.single(e1), .array(e2)):
        return e1 == e2.first
      case let (.array(e1), .single(e2)):
        return e1.first == e2
      case let (.array(e1), .array(e2)):
        return e1 == e2
      default:
        return false
      }
    }

    func hash(into hasher: inout Hasher) {
      switch self {
      case .empty:
        hasher.combine(0)
      case let .single(element):
        hasher.combine(1)
        hasher.combine(element)
      case let .array(elements):
        hasher.combine(elements)
      }

    }
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
    let joined = self.storage.elements
      .map {
        if $0.base is any StringProtocol {
          return "\"\($0.description)\""
        }
        return $0.description
      }
      .joined(separator: ", ")
    return "QueryPath([\(joined)])"
  }
}
