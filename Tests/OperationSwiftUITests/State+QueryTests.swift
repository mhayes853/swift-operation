#if canImport(SwiftUI)
  import SwiftUI
  import ViewInspector
  import XCTest
  import OperationSwiftUI
  import OperationTestHelpers
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
      ViewHosting.host(view: view.operationClient(OperationClient()))

      XCTAssertNoThrow(try view.inspect().find(viewWithId: TestOperationStatusID.idle))
    }

    func testIsLoading() async throws {
      TestStateQuery.action.withLock { $0 = .suspend }
      let view = QueryView()
      ViewHosting.host(view: view.operationClient(OperationClient()))

      try await view.inspection.inspect { try $0.find(button: "Fetch").tap() }
      let expectation = view.inspection.inspect(after: 0.3) { view in
        XCTAssertNoThrow(try view.find(viewWithId: TestOperationStatusID.loading))
      }
      await self.fulfillment(of: [expectation], timeout: 0.5)
    }

    func testSuccess() async throws {
      let view = QueryView()
      ViewHosting.host(view: view.operationClient(OperationClient()))

      try await view.inspection.inspect { try $0.find(button: "Fetch").tap() }
      let expectation = view.inspection.inspect(after: 0.3) { view in
        XCTAssertNoThrow(
          try view.find(viewWithId: TestOperationStatusID.success(TestStateQuery.successValue))
        )
      }
      await self.fulfillment(of: [expectation], timeout: 0.5)
    }

    func testFailure() async throws {
      TestStateQuery.action.withLock { $0 = .fail }
      let view = QueryView()
      ViewHosting.host(view: view.operationClient(OperationClient()))

      try await view.inspection.inspect { try $0.find(button: "Fetch").tap() }
      let expectation = view.inspection.inspect(after: 0.3) { view in
        XCTAssertNoThrow(
          try view.find(viewWithId: TestOperationStatusID.error(TestStateQuery.SomeError()))
        )
      }
      await self.fulfillment(of: [expectation], timeout: 0.5)
    }
  }

  private enum TestOperationStatusID: Hashable {
    case loading
    case idle
    case success(String)
    case error(TestStateQuery.SomeError)
  }

  private struct QueryView: View {
    @State.Operation(TestStateQuery()) private var query

    let inspection = Inspection<Self>()

    var body: some View {
      VStack {
        switch self.$query.status {
        case .idle:
          Text("Idle").id(TestOperationStatusID.idle)
        case .loading:
          Text("Loading").id(TestOperationStatusID.loading)
        case .result(.success(let data)):
          Text("Success: \(data)").id(TestOperationStatusID.success(data))
        case .result(.failure(let error as TestStateQuery.SomeError)):
          Text("Failure: \(error.localizedDescription)")
            .id(TestOperationStatusID.error(error))
        default:
          Text("Unknown")
        }

        Button("Fetch") {
          Task { try await self.$query.fetch() }
        }
      }
      .onReceive(self.inspection.notice) { self.inspection.visit(self, $0) }
    }
  }
#endif
