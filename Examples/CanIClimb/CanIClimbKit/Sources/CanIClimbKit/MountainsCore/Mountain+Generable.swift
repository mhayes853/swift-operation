import Foundation
import FoundationModels

extension Mountain {
  @Generable
  public struct Generable: Hashable, Sendable {
    @Guide(description: "The name of the mountain.")
    public var name: String

    @Guide(description: "A textual description of the mountain.")
    public var description: String

    @Guide(description: "The elevation of the mountain's peak in meters.")
    public var peakElevation: String

    @Guide(description: "A human-readable name for the mountain's location.")
    public var locationName: String

    @Guide(description: "A latitude - longitude coordinate of the mountain's location.")
    public var locationCoordinate: LocationCoordinate2D.Generable

    @Guide(description: "A textual description of the mountain's climbing difficulty out of 100.")
    public var climbingDifficulty: String

    @Guide(description: "A textual description of the mountain's climbing difficulty rating.")
    public var climbingDifficultyRating: String

    public init(mountain: Mountain) {
      self.name = mountain.name
      self.description = mountain.displayDescription
      self.peakElevation = mountain.elevation.converted(to: .meters)
        .formatted(.measurement(width: .abbreviated, usage: .asProvided))
      self.locationName = String(localized: mountain.location.name.localizedStringResource)
      self.locationCoordinate = LocationCoordinate2D.Generable(
        coordinate: mountain.location.coordinate
      )
      self.climbingDifficulty = "\(mountain.difficulty.rawValue) out of 100"
      self.climbingDifficultyRating = String(
        localized: mountain.difficulty.rating.localizedStringResource
      )
    }
  }
}
