import SwiftUI

extension View {
  public func dismissable() -> some View {
    self.modifier(DismissableModifier())
  }
}

private struct DismissableModifier: ViewModifier {
  @Environment(\.dismiss) private var dismiss

  func body(content: Content) -> some View {
    content
      .toolbar {
        let button = Button {
          self.dismiss()
        } label: {
          Image(systemName: "xmark")
        }
        #if os(iOS)
          ToolbarItem(placement: .topBarLeading) {
            button
          }
        #else
          ToolbarItem(placement: .navigation) {
            button
          }
        #endif
      }
  }
}
