import SwiftUI

public struct ProfileCircleView: View {
  private let height: CGFloat

  public init(height: CGFloat) {
    self.height = height
  }

  public var body: some View {
    Image(systemName: "person.fill")
      .resizable()
      .scaledToFit()
      .foregroundStyle(.white)
      .scaleEffect(0.75)
      .offset(y: self.height * 0.1)
      .background(Color.gray.gradient)
      .clipShape(Circle())
      .frame(height: self.height)
  }
}
