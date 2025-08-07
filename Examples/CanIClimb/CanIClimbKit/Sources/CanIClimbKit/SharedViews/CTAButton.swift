import SwiftUI

public struct CTAButton: View {
  private let action: () -> Void
  private let label: LocalizedStringKey
  private let systemImage: String?

  public init(
    _ label: LocalizedStringKey,
    systemImage: String? = nil,
    action: @escaping () -> Void
  ) {
    self.action = action
    self.label = label
    self.systemImage = systemImage
  }

  public var body: some View {
    Button(action: self.action) {
      HStack {
        if let systemImage = self.systemImage {
          Image(systemName: systemImage)
        }
        Text(self.label)
      }
      .foregroundStyle(.background)
      .bold()
      .padding()
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .tint(.primary)
  }
}
