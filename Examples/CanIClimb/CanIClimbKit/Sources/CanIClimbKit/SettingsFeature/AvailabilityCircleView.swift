import SwiftUI

struct AvailabilityCircleView: View {
  let isAvailable: Bool

  var body: some View {
    Circle()
      .fill(self.isAvailable ? Color.green.gradient : Color.red.gradient)
      .frame(width: 10, height: 10)
  }
}
