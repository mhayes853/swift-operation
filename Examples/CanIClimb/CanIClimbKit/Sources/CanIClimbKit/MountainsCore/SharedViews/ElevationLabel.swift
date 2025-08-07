import SwiftUI

public struct ElevationLabel: View {
  private let elevation: Measurement<UnitLength>

  public init(elevation: Measurement<UnitLength>) {
    self.elevation = elevation
  }

  public var body: some View {
    HStack(alignment: .center) {
      Image(systemName: "mountain.2.fill")
      Text(
        self.elevation.converted(to: .feet)
          .formatted(.measurement(width: .abbreviated, usage: .asProvided))
      )
    }
    .font(.footnote)
  }
}
