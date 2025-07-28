import SwiftUI

extension View {
  public func inlineNavigationTitle(_ title: LocalizedStringResource) -> some View {
    self.navigationTitle(title)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
  }
}
