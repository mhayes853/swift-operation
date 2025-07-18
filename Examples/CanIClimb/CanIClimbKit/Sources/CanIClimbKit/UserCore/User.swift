import Foundation
import Tagged

// MARK: - User

public typealias User = CachedUserRecord

extension User {
  public typealias ID = Tagged<Self, String>
}

// MARK: - Mocks

extension User {
  public static let mock1 = User(id: "test", name: PersonNameComponents(familyName: "Blob"))
  public static let mock2 = User(id: "test", name: PersonNameComponents(familyName: "Blob 2"))
}
