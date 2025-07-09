import Foundation
import Tagged

// MARK: - User

public struct User: Hashable, Sendable, Identifiable, Codable {
  public typealias ID = Tagged<Self, String>

  public let id: ID
  public var name: PersonNameComponents

  public init(id: ID, name: PersonNameComponents) {
    self.id = id
    self.name = name
  }
}

// MARK: - Mocks

extension User {
  public static let mock1 = User(id: "test", name: PersonNameComponents(familyName: "Blob"))
  public static let mock2 = User(id: "test", name: PersonNameComponents(familyName: "Blob 2"))
}
