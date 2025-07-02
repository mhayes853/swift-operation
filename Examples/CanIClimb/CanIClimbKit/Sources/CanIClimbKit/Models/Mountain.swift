import Foundation
import Tagged

// MARK: - Mountain

public struct Mountain: Hashable, Sendable, Codable {
  public typealias ID = Tagged<Self, UUID>

  public let id: ID
  public var name: String
  public var displayDescription: String
  public var elevation: Measurement<UnitLength>
  public var location: LocationCoordinate2D
  public var dateAdded: Date
  public var difficulty: Difficulty
  public var imageURL: URL

  public init(
    id: Mountain.ID,
    name: String,
    displayDescription: String,
    elevation: Measurement<UnitLength>,
    location: LocationCoordinate2D,
    dateAdded: Date,
    difficulty: Difficulty,
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
  public enum Difficulty: Int, Hashable, Sendable, Codable {
    case easy
    case moderate
    case difficult
    case veryDifficult
  }
}
