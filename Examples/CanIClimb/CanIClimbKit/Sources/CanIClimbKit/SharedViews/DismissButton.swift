import SwiftUI

extension View {
  public func dismissable(onDismiss: (() -> Void)? = nil) -> some View {
    self.modifier(DismissableModifier(onDismiss: onDismiss))
  }
}

private struct DismissableModifier: ViewModifier {
  @Environment(\.dismiss) private var dismiss
  let onDismiss: (() -> Void)?

  func body(content: Content) -> some View {
    content
      .toolbar {
        #if os(iOS)
          ToolbarItem(placement: .topBarLeading) {
            Button {
              if let onDismiss {
                onDismiss()
              } else {
                self.dismiss()
              }
            } label: {
              Image(systemName: "xmark")
            }
          }
        #endif
      }
  }
}
