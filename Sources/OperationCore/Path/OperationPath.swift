// MARK: - OperationPath

/// A data type that uniquely identifies a ``StatefulOperationRequest``.
///
/// You can opt to manually implement ``StatefulOperationRequest/path-3dph9`` when your operation
/// does not conform to Hashable or Identifiable like so.
///
/// ```swift
/// struct UserByNameQuery: QueryRequest {
///   let name: String
///
///   var path: OperationPath {
///     ["user", name]
///   }
///
///   // ...
/// }
/// ```
///
/// If you have multiple views using `UserByNameQuery`, you can access all instances of the query
/// state for those views by pattern matching with an ``OperationClient``.
///
/// ```swift
/// // Retrieves all OperationStore instances for every UserByNameQuery
/// // in the app.
/// let stores = client.stores(
///   matching: ["user"],
///   as: UserByNameQuery.State.self
/// )
/// ```
///
/// > Note: See <doc:PatternMatchingAndStateManagement> to learn best practicies for managing your
/// > global application state using `OperationPath`.
public struct OperationPath: Hashable, Sendable {
  private var storage: Storage

  /// Creates an empty path.
  public init() {
    self.storage = .empty
  }
}

// MARK: - Array Init

extension OperationPath {
  /// Creates a path from an array of Hashable and Sendable elements.
  ///
  /// This initializer will wrap each element of the sequence in an ``Element`` instance. If you
  /// wish to construct a path from a sequence of literal `Element` instances, use
  /// ``init(elements:)`` instead.
  ///
  /// - Parameter elements: The elements that make up this path.
  public init(_ elements: some Sequence<any Hashable & Sendable>) {
    self.init(elements: elements.map(Element.init))
  }

  /// Constructs a path from a sequence of ``Element`` instances.
  ///
  /// - Parameter elements: The elements that make up this path.
  public init(elements: some Sequence<Element>) {
    self.storage = .array(Array(elements))
  }
}

// MARK: - Single Element Init

extension OperationPath {
  /// Creates a path from a single element.
  ///
  /// This initializer will wrap the element in an ``Element`` instance. If you wish to construct a
  /// path from a literal `Element` instance, use ``init(element:)`` instead.
  ///
  /// - Parameter element: The sole element that makes up this path.
  @_disfavoredOverload
  public init(_ element: some Hashable & Sendable) {
    self.init(element: Element(element))
  }

  /// Constructs a path from a single ``Element`` instance.
  ///
  /// - Parameter element: The sole element that makes up this path.
  public init(element: Element) {
    self.storage = .single(element)
  }
}

// MARK: - Matches

extension OperationPath {
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

extension OperationPath {
  /// Appends the contents of `other` to this path.
  ///
  /// - Parameter other: Another path.
  public mutating func append(_ other: OperationPath) {
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
    self.append(OperationPath(element))
  }

  /// Returns a new path with the contents of this path appended with the contents of `other`.
  ///
  /// - Parameter other: Another path.
  /// - Returns: A new path with the contents of this path appended with the contents of `other`.
  public func appending(_ other: OperationPath) -> Self {
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

extension OperationPath {
  private enum Storage: Hashable, Sendable {
    case empty
    case single(Element)
    case array([Element])

    var elements: any RandomAccessCollection<Element> {
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

extension OperationPath: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: (any Hashable & Sendable)...) {
    self.init(elements)
  }
}

// MARK: - CustomStringConvertible

extension OperationPath: CustomStringConvertible {
  public var description: String {
    let joined = self.storage.elements
      .map {
        if $0.base is any StringProtocol {
          return "\"\($0.description)\""
        }
        return $0.description
      }
      .joined(separator: ", ")
    return "OperationPath([\(joined)])"
  }
}

// MARK: - Element

extension OperationPath {
  public struct Element: Hashable, Sendable {
    private let inner: AnyHashableSendable

    /// The underlying value of this element.
    public var base: any Hashable & Sendable {
      self.inner.base
    }

    /// Creates an element.
    ///
    /// - Parameter value: A Hashable and Sendable value.
    public init(_ value: any Hashable & Sendable) {
      self.inner = AnyHashableSendable(value)
    }
  }
}

extension OperationPath.Element: CustomStringConvertible {
  public var description: String {
    self.inner.description
  }
}

// MARK: - MutableCollection

extension OperationPath: MutableCollection {
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
      case .single(let element): yield element
      case .array(let elements): yield elements[position]
      case .empty: fatalError()  // NB: Unreachable due to checkIndexPrecondition.
      }
    }
    set {
      self.checkIndexPrecondition(position: position)
      switch self.storage {
      case .single:
        self.storage = .single(newValue)
      case .array(var elements):
        elements[position] = newValue
        self.storage = .array(elements)
      case .empty:
        fatalError()  // NB: Unreachable due to checkIndexPrecondition.
      }
    }
  }
}

// MARK: - RandomAccessCollection

extension OperationPath: RandomAccessCollection {
}

// MARK: - RangeReplaceableCollection

extension OperationPath: RangeReplaceableCollection {
  public mutating func replaceSubrange(
    _ subrange: Range<Int>,
    with newElements: some Collection<Element>
  ) {
    let kind = subrange.isEmpty ? IndexKind.insertion : .access
    switch kind {
    case .access:
      self.checkIndexPrecondition(position: subrange.lowerBound)
      self.checkIndexPrecondition(position: subrange.upperBound - 1)
    case .insertion:
      self.checkIndexPrecondition(position: subrange.startIndex, kind: kind)
    }

    switch (self.storage, kind) {
    case (.single, .access):
      if let first = newElements.first {
        self.storage = .single(first)
      } else {
        self.storage = .empty
      }
    case (.single(let element), .insertion):
      guard let first = newElements.first else { break }
      if subrange.startIndex == self.startIndex {
        self.storage = .array([first, element])
      } else {
        self.storage = .array([element, first])
      }
    case (.array(var elements), _):
      elements.replaceSubrange(subrange, with: newElements)
      self.storage = .array(elements)
    case (.empty, .insertion):
      if let first = newElements.first {
        self.storage = .single(first)
      }
    case (.empty, .access):
      break  // NB: Unreachable due to checkIndexPrecondition.
    }
  }
}

// MARK: - Check Index

extension OperationPath {
  package static let _indexOutOfRangeMessage = "OperationPath index out of range"

  private enum IndexKind {
    case access
    case insertion
  }

  private func checkIndexPrecondition(position: Index, kind: IndexKind = .access) {
    switch (self.storage, kind) {
    case (.empty, .access):
      preconditionFailure(Self._indexOutOfRangeMessage)
    case (.empty, .insertion):
      precondition(position == 0, Self._indexOutOfRangeMessage)
    case (.single, .access):
      precondition(self.startIndex == position, Self._indexOutOfRangeMessage)
    case (.single, .insertion):
      precondition(
        (self.startIndex...self.endIndex).contains(position),
        Self._indexOutOfRangeMessage
      )
    case (.array(let elements), .access):
      precondition(
        (elements.startIndex..<elements.endIndex).contains(position),
        Self._indexOutOfRangeMessage
      )
    case (.array(let elements), .insertion):
      precondition(
        (elements.startIndex...elements.endIndex).contains(position),
        Self._indexOutOfRangeMessage
      )
    }
  }
}
