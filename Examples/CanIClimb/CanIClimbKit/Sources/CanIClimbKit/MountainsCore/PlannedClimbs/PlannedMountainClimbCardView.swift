import SwiftUI

public struct PlannedMountainClimbCardView: View {
  @Environment(\.colorScheme) private var colorScheme
  @ScaledMetric private var cardHeight = CGFloat(100)

  @ScaledMetric private var iconSize = CGFloat(40)

  private let plannedClimb: Mountain.PlannedClimb

  public init(plannedClimb: Mountain.PlannedClimb) {
    self.plannedClimb = plannedClimb
  }

  public var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Image(systemName: "figure.climbing")
          .frame(width: self.iconSize)
        Text(self.plannedClimb.targetDate.formatted(.dateTime))
      }
      .font(.headline)

      Spacer()

      HStack {
        Image(systemName: "medal.fill")
          .frame(width: self.iconSize)
        if let achievedDate = self.plannedClimb.achievedDate {
          Text("Completed on \(achievedDate.formatted(.dateTime))")
        } else {
          Text("To be completed")
        }
      }
      .foregroundStyle(self.plannedClimb.achievedDate == nil ? Color.secondary : Color.green)
      .font(.footnote)

      HStack(alignment: .center) {
        Image(systemName: "alarm.waves.left.and.right.fill")
          .frame(width: self.iconSize)
        if let alarm = self.plannedClimb.alarm {
          Text("Alarm set for \(alarm.date.formatted(.dateTime))")
        } else {
          Text("No alarm set")
        }
      }
      .foregroundStyle(.secondary)
      .font(.footnote)
      Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: self.cardHeight)
    .background(
      self.colorScheme == .dark
        ? AnyShapeStyle(Color.secondaryBackground)
        : AnyShapeStyle(.background)
    )
    .clipShape(RoundedRectangle(cornerRadius: 30))
  }
}
