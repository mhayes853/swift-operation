import CasePaths
import Foundation
import FoundationModels

// MARK: - ClimbReadiness

@Generable
public struct MountainClimbReadiness: Hashable, Sendable, Codable {
  @Guide(description: "The rating for how ready the user is for climbing the mountain.")
  public var rating: Rating

  @Guide(description: "A justification for the rating alongside climbing preparation advice.")
  public var insight: String

  public init(rating: MountainClimbReadiness.Rating, insight: String) {
    self.rating = rating
    self.insight = insight
  }
}

extension MountainClimbReadiness.PartiallyGenerated: Sendable {}

// MARK: - Rating

extension MountainClimbReadiness {
  @Generable
  public enum Rating: Hashable, Sendable, Codable {
    case notReady
    case partiallyReady
    case ready
  }
}

// MARK: - Mocks

extension MountainClimbReadiness {
  public static let mock = Self(
    rating: .partiallyReady,
    insight: "You need to buy hiking shoes in order to climb this mountain."
  )
}
