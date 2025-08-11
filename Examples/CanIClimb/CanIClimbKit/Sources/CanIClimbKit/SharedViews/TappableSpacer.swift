import SwiftUI

public struct TappableSpacer: View {
  // NB: The area filled by Spacer in a button is not tappable, so this hack view will make
  // that area tappable.
  public init() {}

  public var body: some View {
    Color.red.opacity(0.000001)
      .frame(maxWidth: .infinity)
  }
}
