import Foundation
import Tagged

// MARK: - User

public typealias User = CachedUserRecord

// MARK: - ID

extension User {
  public typealias ID = Tagged<Self, String>
}

// MARK: - Name

extension User {
  public struct Name: Hashable, Sendable {
    public private(set) var components: PersonNameComponents

    public init(components: PersonNameComponents) {
      self.components = components
    }
  }
}

extension User.Name {
  public init?(_ name: String) {
    guard !name.isEmpty else { return nil }
    self.components = PersonNameComponents()
    if let components = try? PersonNameComponents(name) {
      self.components = components
    } else {
      self.components.givenName = name
    }
  }
}

extension User.Name {
  public func formatted() -> String {
    self.components.formatted()
  }
}

extension User.Name: Encodable {
  public func encode(to encoder: any Encoder) throws {
    try self.components.encode(to: encoder)
  }
}

extension User.Name: Decodable {
  public init(from decoder: any Decoder) throws {
    self.components = try PersonNameComponents(from: decoder)
  }
}

// MARK: - Mocks

extension User {
  public static let mock1 = User(id: "test", name: Name("Blob")!)
  public static let mock2 = User(id: "test 2", name: Name("Blob 2")!)
}
