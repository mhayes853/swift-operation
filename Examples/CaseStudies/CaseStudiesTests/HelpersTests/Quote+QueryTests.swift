import CustomDump
import Dependencies
import Foundation
import SharingOperation
import Testing

@testable import CaseStudies

struct CaseStudiesTests {
  @Test("Returns Data From Zenquotes")
  func returnsDataFromZenquotes() async throws {
    let payload = """
      {
        "id": 1405,
        "quote": "When I Look Into The Future, It'S So Bright It Burns My Eyes.",
        "author": "Oprah Winfrey"
      }
      """
    let transport = MockHTTPDataTransport { _ in
      (200, .data(Data(payload.utf8)))
    }
    try await withDependencies {
      $0[QuoteRandomLoaderKey.self] = DummyJSONAPI(transport: transport)
    } operation: {
      @SharedQuery(Quote.randomQuery) var quote
      try await $quote.load()
      let expectedQuote = Quote(
        author: "Oprah Winfrey",
        content: "When I Look Into The Future, It'S So Bright It Burns My Eyes."
      )
      expectNoDifference(quote, expectedQuote)
    }
  }
}
