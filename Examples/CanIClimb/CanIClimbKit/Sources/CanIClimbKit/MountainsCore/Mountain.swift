import Foundation
import SwiftUI
import Tagged
import UUIDV7

// MARK: - Mountain

public struct Mountain: Hashable, Sendable, Codable, Identifiable {
  public typealias ID = Tagged<Self, UUIDV7>

  public var id: ID
  public var name: String
  public var displayDescription: String
  public var elevation: Measurement<UnitLength>
  public var coordinate: LocationCoordinate2D
  public var locationName: LocationName
  public var dateAdded: Date
  public var difficulty: ClimbingDifficulty
  public var imageURL: URL

  public init(
    id: Mountain.ID,
    name: String,
    displayDescription: String,
    elevation: Measurement<UnitLength>,
    coordinate: LocationCoordinate2D,
    locationName: LocationName,
    dateAdded: Date,
    difficulty: ClimbingDifficulty,
    imageURL: URL
  ) {
    self.id = id
    self.name = name
    self.displayDescription = displayDescription
    self.elevation = elevation
    self.coordinate = coordinate
    self.locationName = locationName
    self.dateAdded = dateAdded
    self.difficulty = difficulty
    self.imageURL = imageURL
  }
}

// MARK: - ClimbingDifficulty

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

extension Mountain.ClimbingDifficulty.Rating: CustomLocalizedStringResourceConvertible {
  public var localizedStringResource: LocalizedStringResource {
    switch self {
    case .easy: "Easy"
    case .moderate: "Moderate"
    case .difficult: "Difficult"
    case .veryDifficult: "Very Difficult"
    case .extreme: "Extreme"
    }
  }
}

extension Color {
  public init(rating: Mountain.ClimbingDifficulty.Rating) {
    switch rating {
    case .easy: self = .blue
    case .moderate: self = .green
    case .difficult: self = .yellow
    case .veryDifficult: self = .orange
    case .extreme: self = .red
    }
  }
}

// MARK: - LocationName

extension Mountain {
  public struct LocationName: Hashable, Sendable, Codable {
    public var part1: String
    public var part2: String

    public init(part1: String, part2: String) {
      self.part1 = part1
      self.part2 = part2
    }
  }
}

extension Mountain.LocationName: CustomLocalizedStringResourceConvertible {
  public var localizedStringResource: LocalizedStringResource {
    "\(self.part1), \(self.part2)"
  }
}

// MARK: - Mocks

extension Mountain {
  public static let mock1 = Self(
    id: ID(),
    name: "Mt. Stupid",
    displayDescription: "A mountain composed of stupidity.",
    elevation: Measurement(value: 20_000, unit: .feet),
    coordinate: LocationCoordinate2D(latitude: 45, longitude: 45),
    locationName: LocationName(part1: "Dunning", part2: "Krugger"),
    dateAdded: Date(timeIntervalSince1970: 0),
    difficulty: ClimbingDifficulty(rawValue: 47)!,
    imageURL: URL(
      string:
        "https://paragliding.ch/wp-content/uploads/2024/03/Bildschirmfoto-2024-03-07-um-22.18.44.png"
    )!
  )

  public static let mock2 = Self(
    id: ID(),
    name: "Olympus Mons",
    displayDescription: "A cool mountain on Mars.",
    elevation: Measurement(value: 69_648.95, unit: .feet),
    coordinate: LocationCoordinate2D(latitude: 45, longitude: 45),
    locationName: LocationName(part1: "Western Tharsis Rise", part2: "Mars"),
    dateAdded: Date(timeIntervalSince1970: 0),
    difficulty: ClimbingDifficulty(rawValue: 100)!,
    imageURL: URL(
      string:
        "https://lowell.edu/wp-content/uploads/2020/09/maxresdefault-1024x576.jpg"
    )!
  )
}
