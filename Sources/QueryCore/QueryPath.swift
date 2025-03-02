import ConcurrencyExtras

// MARK: - QueryPath

public struct QueryPath: Hashable, Sendable {
  private let elements: [AnyHashableSendable]

  public init(_ elements: [any Hashable & Sendable] = []) {
    self.elements = elements.map(AnyHashableSendable.init)
  }
}

// MARK: - Matches

extension QueryPath {
  public func prefixMatches(other: Self) -> Bool {
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
