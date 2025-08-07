import SwiftUI

public struct MountainDifficultyView: View {
  private let difficulty: Mountain.ClimbingDifficulty

  public init(difficulty: Mountain.ClimbingDifficulty) {
    self.difficulty = difficulty
  }

  public var body: some View {
    Group {
      let formattedDifficulty = self.difficulty.rawValue.formatted(.number)
      let formattedRating = self.difficulty.rating.localizedStringResource
      Text("\(formattedRating): \(formattedDifficulty)")
    }
    .font(.footnote.bold())
    .foregroundStyle(.white)
    .padding(10)
    .background(Color(rating: self.difficulty.rating).gradient)
    .clipShape(Capsule())
  }
}
