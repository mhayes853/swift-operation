import FoundationModels

// MARK: - ClimbReadiness

extension Mountain {
  @Generable
  public struct ClimbReadiness: Hashable, Sendable, Codable {
    @Guide(description: "The rating for how ready the user is for climbing the mountain.")
    public var rating: Rating

    @Guide(description: "A justification for the rating alongside climbing preparation advice.")
    public var insight: String

    public init(rating: Mountain.ClimbReadiness.Rating, insight: String) {
      self.rating = rating
      self.insight = insight
    }
  }
}

extension Mountain.ClimbReadiness.PartiallyGenerated: Sendable {}

// MARK: - Rating

extension Mountain.ClimbReadiness {
  @Generable
  public enum Rating: Hashable, Sendable, Codable {
    case notReady
    case partiallyReady
    case ready
  }
}

// MARK: - Mocks

extension Mountain.ClimbReadiness {
  public static let mock = Self(
    rating: .partiallyReady,
    insight: "You need to buy hiking shoes in order to climb this mountain."
  )
}
