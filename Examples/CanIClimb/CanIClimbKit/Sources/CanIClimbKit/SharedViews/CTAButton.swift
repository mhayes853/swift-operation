import SwiftUI

public struct CTAButton: View {
  private let action: () -> Void
  private let label: LocalizedStringKey

  public init(_ label: LocalizedStringKey, action: @escaping () -> Void) {
    self.action = action
    self.label = label
  }

  public var body: some View {
    Button(action: self.action) {
      Text(self.label)
        .foregroundStyle(.background)
        .bold()
        .padding()
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .tint(.primary)
  }
}
