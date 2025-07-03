import SwiftUI

// MARK: - HumanGender

public enum HumanGender: String, Hashable, Sendable, CaseIterable {
  case male
  case female
  case nonBinary
}

// MARK: - LocalizedString

extension HumanGender {
  public var localizedString: LocalizedStringKey {
    switch self {
    case .male: "Male"
    case .female: "Female"
    case .nonBinary: "Non-binary"
    }
  }
}
