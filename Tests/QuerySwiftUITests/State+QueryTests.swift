#if canImport(SwiftUI)
  import SwiftUI
  import ViewInspector
  import XCTest
  import QuerySwiftUI
  import CustomDump
  import Combine

  @MainActor
  final class StateQueryTests: XCTestCase {
    override func setUp() {
      TestStateQuery.action.withLock { $0 = .load }
    }

    override func tearDown() {
      ViewHosting.expel()
    }

    func testIdleByDefault() throws {
      let view = QueryView()
      ViewHosting.host(view: view)

      XCTAssertNoThrow(try view.inspect().find(viewWithId: TestQueryStatusID.idle))
    }

    func testIsLoading() async throws {
      TestStateQuery.action.withLock { $0 = .suspend }
      let view = QueryView()
      ViewHosting.host(view: view.environment(\.queryClient, QueryClient()))

      try await view.inspection.inspect { try $0.find(button: "Fetch").tap() }
      let expectation = view.inspection.inspect(after: 0.05) { view in
        XCTAssertNoThrow(try view.find(viewWithId: TestQueryStatusID.loading))
      }
      await self.fulfillment(of: [expectation], timeout: 0.1)
    }

    func testSuccess() async throws {
      let view = QueryView()
      ViewHosting.host(view: view.environment(\.queryClient, QueryClient()))

      try await view.inspection.inspect { try $0.find(button: "Fetch").tap() }
      let expectation = view.inspection.inspect(after: 0.05) { view in
        XCTAssertNoThrow(
          try view.find(viewWithId: TestQueryStatusID.success(TestStateQuery.successValue))
        )
      }
      await self.fulfillment(of: [expectation], timeout: 0.1)
    }

    func testFailure() async throws {
      TestStateQuery.action.withLock { $0 = .fail }
      let view = QueryView()
      ViewHosting.host(view: view.environment(\.queryClient, QueryClient()))

      try await view.inspection.inspect { try $0.find(button: "Fetch").tap() }
      let expectation = view.inspection.inspect(after: 0.05) { view in
        XCTAssertNoThrow(
          try view.find(viewWithId: TestQueryStatusID.error(TestStateQuery.SomeError()))
        )
      }
      await self.fulfillment(of: [expectation], timeout: 0.1)
    }

    //@Test("Updates Query State When Client Changes")
    //func updatesQueryStateWhenClientChanges() async throws {
    //  let view = ClientWithQueryView()
    //  ViewHosting.host(view: view)
    //  defer { ViewHosting.expel() }

    //  try await view.inspection.inspect { try $0.find(button: "Fetch").tap() }
    //  view.inspection.inspect(after: 0.1) { view in
    //    #expect(throws: Never.self) {
    //      try view.find(text: "Success: \(TestStateQuery.successValue)")
    //    }
    //  }

    //  try await view.inspection.inspect { try $0.find(button: "Reset Client").tap() }
    //  try await view.inspection.inspect { view in
    //    #expect(throws: Never.self) {
    //      try view.find(text: "Idle")
    //    }
    //  }
    //}
  }
#endif
