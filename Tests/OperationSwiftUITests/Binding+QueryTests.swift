#if canImport(SwiftUI)
  import XCTest
  import OperationSwiftUI
  import OperationTestHelpers
  import CustomDump
  import SwiftUI
  import ViewInspector

  @MainActor
  final class BindingQueryTests: XCTestCase {
    private let client = OperationClient()

    override func tearDown() {
      ViewHosting.expel()
    }

    func testIncrement() async throws {
      let view = TestBindingView()
      ViewHosting.host(view: view.operationClient(OperationClient()))

      try await view.inspection.inspect { v in
        try v.find(button: "Increment").tap()
      }

      let expectation = view.inspection.inspect(after: 0.2) { v in
        XCTAssertNoThrow(try v.find(text: "Count 1"))
      }
      await self.fulfillment(of: [expectation], timeout: 1)
    }
  }

  private struct ExampleView: View {
    @State var count = 0

    var body: some View {
      VStack {
        Text("Count \(self.count)")
      }
    }
  }

  private struct TestBindingView: View {
    @State.Operation(TestQuery().disableAutomaticRunning().defaultValue(0))
    var state

    let inspection = Inspection<Self>()

    var body: some View {
      CounterView(count: Binding(self.$state))
        .onReceive(self.inspection.notice) { self.inspection.visit(self, $0) }
    }
  }

  private struct CounterView: View {
    @Binding var count: Int

    var body: some View {
      VStack {
        Button("Increment") {
          self.count += 1
        }
        Text("Count \(self.count)")
      }
    }
  }
#endif
