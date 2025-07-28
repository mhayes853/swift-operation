import SwiftUI

public struct UserCardView: View {
  private let user: User

  @ScaledMetric private var profileHeight = 45

  public init(user: User) {
    self.user = user
  }

  public var body: some View {
    HStack(alignment: .center) {
      ProfileCircleView(height: self.profileHeight)
      VStack(alignment: .leading) {
        Text(self.user.name.formatted()).font(.headline)
        Text(self.user.subtitle == "" ? "No subtitle" : self.user.subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
