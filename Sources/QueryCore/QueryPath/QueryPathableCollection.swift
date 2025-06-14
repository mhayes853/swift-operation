// MARK: - QueryPathableCollection

/// A collection of elements that have an associated ``QueryPath``.
public struct QueryPathableCollection<Element: QueryPathable> {
  private var elements = [QueryPath: Element]()

  /// Creates an empty collection.
  public init() {}
}

// MARK: - Path Subscript

extension QueryPathableCollection {
  /// Returns an element associated with the specified path, if it exists.
  ///
  /// - Parameter path: The path to look up.
  /// - Returns: The element associated with the path, or `nil` if no such element exists.
  public subscript(path: QueryPath) -> Element? {
    _read { yield self.elements[path] }
  }
}

// MARK: - Paths

extension QueryPathableCollection {
  /// The ``QueryPath``s stored in this collection.
  public var paths: Set<QueryPath> {
    Set(self.elements.keys)
  }
}

// MARK: - Removing

extension QueryPathableCollection {
  /// Removes the element associated with the specified path, if it exists.
  ///
  /// - Parameter path: The path to remove.
  /// - Returns: The removed element, or `nil` if no such element exists.
  @discardableResult
  public mutating func removeValue(forPath path: QueryPath) -> Element? {
    self.elements.removeValue(forKey: path)
  }

  /// Removes all elements from this collection.
  ///
  /// - Parameter keepingCapacity: Whether to keep the capacity of the collection.
  public mutating func removeAll(keepingCapacity: Bool = false) {
    self.elements.removeAll(keepingCapacity: keepingCapacity)
  }

  /// Removes all elements from this collection that match the specified path.
  ///
  /// Matching is via the path's ``QueryPath/isPrefix(of:)`` method.
  ///
  /// - Parameter path: The path to match.
  public mutating func removeAll(matching path: QueryPath) {
    self.removeAll { path.isPrefix(of: $0.path) }
  }

  /// Removes all elements from this collection that satisfy the given predicate.
  ///
  /// - Parameter shouldBeRemoved: A closure that takes an element of the sequence as its argument
  ///   and returns a Boolean value indicating whether the element should be removed from the
  ///   collection.
  public mutating func removeAll(where shouldBeRemoved: (Element) -> Bool) {
    var collection = Self()
    for element in self {
      if !shouldBeRemoved(element) {
        collection.update(element)
      }
    }
    self = collection
  }

  /// Removes the element at the specified index.
  ///
  /// - Parameter index: The index of the element to remove.
  /// - Returns: The removed element.
  @discardableResult
  public mutating func remove(at index: Index) -> Element {
    self.elements.remove(at: index.inner).value
  }
}

// MARK: - Update

extension QueryPathableCollection {
  /// Updates the collection with the specified element.
  ///
  /// - Parameter element: The element to update.
  public mutating func update(_ element: Element) {
    self.elements[element.path] = element
  }
}

// MARK: - Capacity

extension QueryPathableCollection {
  /// Reserves capacity for at least the specified number of elements.
  ///
  /// - Parameter minimumCapacity: The minimum number of elements to reserve capacity for.
  public mutating func reserveCapacity(_ minimumCapacity: Int) {
    self.elements.reserveCapacity(minimumCapacity)
  }
}

// MARK: - Matching

extension QueryPathableCollection {
  /// Returns a new collection containing the elements that match the specified path.
  ///
  /// Matching is performed via ``QueryPath/isPrefix(of:)``.
  ///
  /// - Parameter path: The path to match.
  /// - Returns: A new collection containing the elements that match the specified path.
  public func collection(matching path: QueryPath) -> Self {
    guard path != [] else { return self }
    var newValues = Self()
    for value in self {
      if path.isPrefix(of: value.path) {
        newValues.update(value)
      }
    }
    return newValues
  }
}

// MARK: - Collection Conformance

extension QueryPathableCollection: Collection {
  public struct Index: Hashable, Comparable {
    fileprivate let inner: [QueryPath: Element].Index

    public static func < (lhs: Index, rhs: Index) -> Bool {
      lhs.inner < rhs.inner
    }
  }

  public var startIndex: Index {
    Index(inner: self.elements.startIndex)
  }

  public var endIndex: Index {
    Index(inner: self.elements.endIndex)
  }

  public subscript(position: Index) -> Element {
    _read { yield self.elements[position.inner].value }
  }

  public func index(after i: Index) -> Index {
    Index(inner: self.elements.index(after: i.inner))
  }
}

// MARK: - Sequence Init

extension QueryPathableCollection {
  /// Creates a new collection from the specified sequence.
  ///
  /// - Parameter sequence: The sequence to create the collection from.
  public init(_ sequence: some Sequence<Element>) {
    for element in sequence {
      self.elements[element.path] = element
    }
  }
}

// MARK: - ExpressibleByArrayLiteral

extension QueryPathableCollection: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }
}

// MARK: - Conditional Conformances

extension QueryPathableCollection: Equatable where Element: Equatable {}
extension QueryPathableCollection: Hashable where Element: Hashable {}
extension QueryPathableCollection: Sendable where Element: Sendable {}

extension QueryPathableCollection.Index: Sendable where Element: Sendable {}
