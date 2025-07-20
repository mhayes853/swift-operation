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
    case (.single(let e1), .single(let e2)):
      return e1 == e2
    case (.single(let e1), .array(let e2)):
      return e1 == e2.first
    case (.array(let e1), .single(let e2)):
      return e1.count == 1 && e1.first == e2
    case (.array(let e1), .array(let e2)):
      guard e1.count <= e2.count else { return false }
      return (0..<Swift.min(e1.count, e2.count)).allSatisfy { i in e1[i] == e2[i] }
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
    case (.single(let e1), .single(let e2)):
      self.storage = .array([e1, e2])
    case (.single(let e1), .array(let e2)):
      self.storage = .array([e1] + e2)
    case (.array(let e1), .single(let e2)):
      self.storage = .array(e1 + [e2])
    case (.array(let e1), .array(let e2)):
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
      case .single(let element): CollectionOfOne(element)
      case .array(let elements): elements
      }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case (.empty, .empty), (.empty, .array([])), (.array([]), .empty):
        true
      case (.single(let e1), .single(let e2)):
        e1 == e2
      case (.single(let e1), .array(let e2)):
        e1 == e2.first
      case (.array(let e1), .single(let e2)):
        e1.first == e2
      case (.array(let e1), .array(let e2)):
        e1 == e2
      default:
        false
      }
    }

    func hash(into hasher: inout Hasher) {
      switch self {
      case .empty:
        hasher.combine(0)
      case .single(let element):
        hasher.combine(1)
        hasher.combine(element)
      case .array(let elements):
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

// MARK: - MutableCollection

extension QueryPath: MutableCollection {
  public typealias Element = any Hashable & Sendable
  public typealias Index = Int

  public func index(after i: Int) -> Int {
    i + 1
  }

  public var startIndex: Int {
    0
  }

  public var endIndex: Int {
    switch self.storage {
    case .empty: 0
    case .single: 1
    case .array(let elements): elements.endIndex
    }
  }

  public subscript(position: Index) -> Element {
    _read {
      self.checkIndexPrecondition(position: position)
      switch self.storage {
      case .single(let element): yield element.base
      case .array(let elements): yield elements[position].base
      case .empty: fatalError()  // NB: Unreachable due to checkIndexPrecondition.
      }
    }
    set {
      self.checkIndexPrecondition(position: position)
      switch self.storage {
      case .single:
        self.storage = .single(AnyHashableSendable(newValue))
      case .array(var elements):
        elements[position] = AnyHashableSendable(newValue)
        self.storage = .array(elements)
      case .empty:
        fatalError()  // NB: Unreachable due to checkIndexPrecondition.
      }
    }
  }
}

// MARK: - RandomAccessCollection

extension QueryPath: RandomAccessCollection {
}

// MARK: - RangeReplaceableCollection

extension QueryPath: RangeReplaceableCollection {
  public mutating func replaceSubrange(
    _ subrange: Range<Int>,
    with newElements: some Collection<Element>
  ) {
    self.checkIndexPrecondition(position: subrange.lowerBound)
    self.checkIndexPrecondition(position: subrange.upperBound - 1)
    switch self.storage {
    case .single:
      if let first = newElements.first {
        self.storage = .single(AnyHashableSendable(first))
      } else {
        self.storage = .empty
      }
    case .array(var elements):
      elements.replaceSubrange(subrange, with: newElements.map(AnyHashableSendable.init))
      self.storage = .array(elements)
    case .empty:
      fatalError()  // NB: Unreachable due to checkIndexPrecondition.
    }
  }
}

// MARK: - Check Index

extension QueryPath {
  package static let _indexOutOfRangeMessage = "QueryPath index out of range"

  private func checkIndexPrecondition(position: Index) {
    switch self.storage {
    case .empty: preconditionFailure(Self._indexOutOfRangeMessage)
    case .single: precondition(self.startIndex == position, Self._indexOutOfRangeMessage)
    case .array(let elements):
      precondition(
        (elements.startIndex..<elements.endIndex).contains(position),
        Self._indexOutOfRangeMessage
      )
    }
  }
}
