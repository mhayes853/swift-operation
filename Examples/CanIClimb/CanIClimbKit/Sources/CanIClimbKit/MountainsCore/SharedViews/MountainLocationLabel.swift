import SwiftUI

public struct MountainLocationNameLabel: View {
  private let name: Mountain.LocationName

  public init(name: Mountain.LocationName) {
    self.name = name
  }

  public var body: some View {
    HStack(alignment: .center) {
      Image(systemName: "mappin.and.ellipse")
      Text(self.name.localizedStringResource)
    }
    .font(.footnote)
  }
}
