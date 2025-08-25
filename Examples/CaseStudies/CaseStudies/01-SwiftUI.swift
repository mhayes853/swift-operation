import Foundation
import OperationSwiftUI
import SwiftUI

struct BasicSwiftUICaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Basic SwiftUI"
  let description: LocalizedStringKey = """
    Basic usage of the library using the `@State.Operation` property wrapper to fetch a random quote \
    from the Dummy JSON API in SwiftUI.
    """

  @State.Operation(Quote.randomQuery) private var quote

  var content: some View {
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
    BasicSwiftUICaseStudy()
  }
}
