import Foundation
import FoundationModels

extension Mountain {
  @Generable
  public struct Generable: Hashable, Sendable {
    public var name: String
    public var description: String
    public var peakElevation: String
    public var locationName: String
    public var locationCoordinate: LocationCoordinate2D.Generable
    public var climbingDifficulty: String
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
