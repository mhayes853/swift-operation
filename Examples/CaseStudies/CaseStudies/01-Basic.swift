import Foundation
import SharingOperation
import SwiftUI

// MARK: - BasicCaseStudy

struct BasicSwiftUICaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Basic SwiftUI"
  let description: LocalizedStringKey = """
    Basic usage of the library using the `@SharedOperation` property wrapper to fetch a random \
    quote from the Dummy JSON API in SwiftUI.
    
    You can use the `@SharedOperation` property wrapper anywhere including `@Observable` models and \
    UIViewController instances.
    """

  var content: some View {
    InnerView()
  }
}

// MARK: - InnerView

private struct InnerView: View {
  @SharedOperation(Quote.$randomQuery) private var quote

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Random Quote").font(.headline)
      BasicQueryStateView(state: self.$quote.state) { quote in
        QuoteView(quote: quote)
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
