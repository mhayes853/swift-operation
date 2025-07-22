import SwiftUI

public struct UserCardView: View {
  private let user: User

  public init(user: User) {
    self.user = user
  }

  public var body: some View {
    HStack(alignment: .center) {
      Image(systemName: "person.crop.circle")
        .font(.largeTitle)
      VStack(alignment: .leading) {
        Text(self.user.name.formatted()).font(.headline)
        Text(self.user.subtitle == "" ? "No subtitle" : self.user.subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
