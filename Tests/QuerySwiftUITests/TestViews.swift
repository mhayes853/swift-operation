#if canImport(SwiftUI)
  import SwiftUI
  import QuerySwiftUI

  enum TestQueryStatusID: Hashable {
    case loading
    case idle
    case success(String)
    case error(TestStateQuery.SomeError)
  }

  struct QueryView: View {
    @State.Query(query: TestStateQuery()) private var query

    let inspection = Inspection<Self>()

    var body: some View {
      VStack {
        switch self.query.status {
        case .idle:
          Text("Idle").id(TestQueryStatusID.idle)
        case .loading:
          Text("Loading").id(TestQueryStatusID.loading)
        case let .result(.success(data)):
          Text("Success: \(data)").id(TestQueryStatusID.success(data))
        case let .result(.failure(error as TestStateQuery.SomeError)):
          Text("Failure: \(error.localizedDescription)")
            .id(TestQueryStatusID.error(error))
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
