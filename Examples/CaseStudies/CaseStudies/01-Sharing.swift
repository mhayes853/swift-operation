import Foundation
import SharingOperation
import SwiftUI

struct BasicSharingCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Basic swift-sharing"
  let description: LocalizedStringKey = """
    Basic usage of the library using the `@SharedOperation` property wrapper to fetch a random quote \
    from the Dummy JSON API in SwiftUI.

    `@SharedOperation` is a more flexible version of `@State.Operation` that utilizes \
    [swift-sharing](https://github.com/pointfreeco/swift-sharing) under the hood allowing \
    you to easily observe your queries anywhere in your application such as an `@Observable` model.
    """

  var content: some View {
    InnerView()
  }
}

private struct InnerView: View {
  @SharedOperation(Quote.randomQuery) private var quote

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Random Quote").font(.headline)
      BasicQueryStateView(state: self.$quote.state) {
        QuoteView(quote: $0)
      }

      Button("Reload Quote") {
        Task { try await self.$quote.fetch() }
      }
      .disabled(self.$quote.isLoading)
    }
  }
}

#Preview {
  NavigationStack {
    BasicSharingCaseStudy()
  }
}
