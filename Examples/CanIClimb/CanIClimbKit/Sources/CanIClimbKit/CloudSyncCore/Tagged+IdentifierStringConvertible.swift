import Foundation
import SharingGRDB
import Tagged

extension Tagged: @retroactive IdentifierStringConvertible
where RawValue: IdentifierStringConvertible {
  public var rawIdentifier: String { self.rawValue.rawIdentifier }

  public init?(rawIdentifier: String) {
    guard let rawValue = RawValue(rawIdentifier: rawIdentifier) else { return nil }
    self.init(rawValue: rawValue)
  }
}
