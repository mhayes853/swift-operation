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
        let button = Button {
          if let onDismiss {
            onDismiss()
          } else {
            self.dismiss()
          }
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
