import CustomDump
import QueryObservation
import Testing

@Suite("QueryModel tests")
struct QueryModelTests {
  private let client = QueryClient()

  @Test("InitialState Is Current State")
  func initialStateIsCurrentState() {
    //let model = QueryModel(state: .initial)
    //XCTAssertEqual(model.state, .initial)
  }
}
