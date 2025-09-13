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
  public var location: Location
  public var dateAdded: Date
  public var difficulty: ClimbingDifficulty
  public var image: Image

  public init(
    id: Mountain.ID,
    name: String,
    displayDescription: String,
    elevation: Measurement<UnitLength>,
    location: Location,
    dateAdded: Date,
    difficulty: ClimbingDifficulty,
    image: Image
  ) {
    self.id = id
    self.name = name
    self.displayDescription = displayDescription
    self.elevation = elevation
    self.location = location
    self.dateAdded = dateAdded
    self.difficulty = difficulty
    self.image = image
  }
}

// MARK: - Image

extension Mountain {
  public struct Image: Hashable, Sendable, Codable {
    public var url: URL
    public var colorScheme: ColorScheme

    public init(url: URL, colorScheme: ColorScheme) {
      self.url = url
      self.colorScheme = colorScheme
    }
  }
}

extension Mountain.Image {
  public enum ColorScheme: String, Hashable, Sendable, Codable {
    case light
    case dark
  }
}

extension ColorScheme {
  public init(mountainImageScheme: Mountain.Image.ColorScheme) {
    switch mountainImageScheme {
    case .light: self = .light
    case .dark: self = .dark
    }
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

// MARK: - Location

extension Mountain {
  public struct Location: Hashable, Sendable, Codable {
    public var coordinate: LocationCoordinate2D
    public var name: Name

    public init(coordinate: LocationCoordinate2D, name: Mountain.Location.Name) {
      self.coordinate = coordinate
      self.name = name
    }
  }
}

extension Mountain.Location {
  public struct Name: Hashable, Sendable, Codable {
    public var part1: String
    public var part2: String

    public init(part1: String, part2: String) {
      self.part1 = part1
      self.part2 = part2
    }
  }
}

extension Mountain.Location.Name: CustomLocalizedStringResourceConvertible {
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
    location: Location(
      coordinate: LocationCoordinate2D(latitude: 45, longitude: 45),
      name: Location.Name(part1: "Dunning", part2: "Krugger")
    ),
    dateAdded: Date(timeIntervalSince1970: 0),
    difficulty: ClimbingDifficulty(rawValue: 47)!,
    image: Image(
      url: URL(
        string:
          "https://paragliding.ch/wp-content/uploads/2024/03/Bildschirmfoto-2024-03-07-um-22.18.44.png"
      )!,
      colorScheme: .light
    )
  )

  public static let mock2 = Self(
    id: ID(),
    name: "Olympus Mons",
    displayDescription: "A cool mountain on Mars.",
    elevation: Measurement(value: 69_648.95, unit: .feet),
    location: Location(
      coordinate: LocationCoordinate2D(latitude: 45, longitude: 45),
      name: Location.Name(part1: "Western Tharsis Rise", part2: "Mars")
    ),
    dateAdded: Date(timeIntervalSince1970: 0),
    difficulty: ClimbingDifficulty(rawValue: 100)!,
    image: Image(
      url: URL(string: "https://lowell.edu/wp-content/uploads/2020/09/maxresdefault-1024x576.jpg")!,
      colorScheme: .dark
    )
  )

  public static let freelPeak = Self(
    id: ID(),
    name: "Freel Peak",
    displayDescription: """
      Freel Peak is a mountain located in the Carson Range, a spur of the Sierra Nevada, near \
      Lake Tahoe in California.

      The peak is on the boundary between El Dorado County and Alpine County; and the boundary \
      between the Eldorado National Forest and the Humboldt-Toiyabe National Forest. At 10,886 \
      feet (3,318 m), it is the tallest summit in the Carson Range, El Dorado County, and the \
      Tahoe Basin. Due to its elevation, most of the precipitation that falls on the mountain is \
      snow.

      In 1893, the U.S. Geological Survey assigned the name Freel Peak to what was then known as \
      Jobs Peak. James Freel was an early settler in the area.
      """,
    elevation: Measurement(value: 10_886, unit: .feet),
    location: Location(
      coordinate: LocationCoordinate2D(latitude: 38.85747, longitude: -119.90000),
      name: Location.Name(part1: "South Lake Tahoe", part2: "California")
    ),
    dateAdded: .now,
    difficulty: ClimbingDifficulty(rawValue: 72)!,
    image: Image(
      url: URL(
        string:
          "https://tahoetrailguide.com/wp-content/uploads/2020/04/8-17-13_Hiking_Freel_Peak_Jobs_Sister_Jobs_Peak_2_Jared_Manninen_web.jpg"
      )!,
      colorScheme: .light
    )
  )
}
