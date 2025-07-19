import SwiftUI

struct QuoteView: View {
  let quote: Quote

  var body: some View {
    VStack(alignment: .leading) {
      Text(self.quote.content)
      Text("- \(self.quote.author)").font(.footnote.italic())
    }
  }
}
