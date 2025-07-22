import SwiftUI

public struct AvailabilityCircleView: View {
  private let isAvailable: Bool

  public init(isAvailable: Bool) {
    self.isAvailable = isAvailable
  }

  public var body: some View {
    Circle()
      .fill(self.isAvailable ? Color.green.gradient : Color.red.gradient)
      .frame(width: 10, height: 10)
  }
}
