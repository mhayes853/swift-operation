import Foundation
import Tagged
import UUIDV7

// MARK: - Mountain

public struct Mountain: Hashable, Sendable, Codable, Identifiable {
  public typealias ID = Tagged<Self, UUIDV7>

  public var id: ID
  public var name: String
  public var displayDescription: String
  public var elevation: Measurement<UnitLength>
  public var location: LocationCoordinate2D
  public var dateAdded: Date
  public var difficulty: ClimbingDifficulty
  public var imageURL: URL

  public init(
    id: Mountain.ID,
    name: String,
    displayDescription: String,
    elevation: Measurement<UnitLength>,
    location: LocationCoordinate2D,
    dateAdded: Date,
    difficulty: ClimbingDifficulty,
    imageURL: URL
  ) {
    self.id = id
    self.name = name
    self.displayDescription = displayDescription
    self.elevation = elevation
    self.location = location
    self.dateAdded = dateAdded
    self.difficulty = difficulty
    self.imageURL = imageURL
  }
}

// MARK: - Difficulty

extension Mountain {
  public struct ClimbingDifficulty: RawRepresentable, Hashable, Sendable, Codable {
    public var rawValue: Double

    public init?(rawValue: RawValue) {
      guard (0...100).contains(rawValue) else { return nil }
      self.rawValue = rawValue
    }
  }
}

extension Mountain.ClimbingDifficulty {
  public enum Rating: Hashable, Sendable {
    case easy
    case moderate
    case difficult
    case veryDifficult
    case extreme
  }

  public var rating: Rating {
    switch self.rawValue {
    case 0...25: .easy
    case 25..<50: .moderate
    case 50..<75: .difficult
    case 75..<90: .veryDifficult
    default: .extreme
    }
  }
}

// MARK: - Mocks

extension Mountain {
  public static let mock1 = Self(
    id: ID(),
    name: "Mt. Stupid",
    displayDescription: "A mountain composed of stupidity.",
    elevation: Measurement(value: 20_000, unit: .feet),
    location: LocationCoordinate2D(latitude: 45, longitude: 45),
    dateAdded: Date(timeIntervalSince1970: 0),
    difficulty: ClimbingDifficulty(rawValue: 47)!,
    imageURL: URL(
      string:
        "https://paragliding.ch/wp-content/uploads/2024/03/Bildschirmfoto-2024-03-07-um-22.18.44.png"
    )!
  )
}
