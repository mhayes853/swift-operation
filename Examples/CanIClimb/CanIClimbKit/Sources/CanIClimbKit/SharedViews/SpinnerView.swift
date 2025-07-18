import SwiftUI

struct SpinnerView: View {
  // NB: ProgressViews tend to behave weirdly with the SwiftUI diffing algorrithm, so generate
  // this UUID every single time to ensure the diffing algorithm detects changes. We cannot
  // generate this UUID in the body because SwiftUI's diffing algorithm won't detect it as
  // different.
  let id = UUID()

  var body: some View {
    ProgressView().id(self.id)
  }
}
