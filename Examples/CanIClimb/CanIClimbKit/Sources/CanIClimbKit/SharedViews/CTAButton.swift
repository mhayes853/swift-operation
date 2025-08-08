import SwiftUI

public struct CTAButton: View {
  private let action: () -> Void
  private let label: LocalizedStringKey
  private let systemImage: String?
  private let tint: Color
  private var foregroundStyle: AnyShapeStyle

  public init(
    _ label: LocalizedStringKey,
    systemImage: String? = nil,
    tint: Color = Color.primary,
    foregroundStyle: AnyShapeStyle = AnyShapeStyle(.background),
    action: @escaping () -> Void
  ) {
    self.action = action
    self.label = label
    self.systemImage = systemImage
    self.tint = tint
    self.foregroundStyle = foregroundStyle
  }

  public var body: some View {
    Button(action: self.action) {
      HStack {
        if let systemImage = self.systemImage {
          Image(systemName: systemImage)
        }
        Text(self.label)
      }
      .foregroundStyle(self.foregroundStyle)
      .bold()
      .padding()
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .tint(self.tint)
  }
}
