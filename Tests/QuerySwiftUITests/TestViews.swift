#if canImport(SwiftUI)
  import SwiftUI
  import QuerySwiftUI

  struct ClientWithQueryView: View {
    @State private var client = QueryClient()

    let inspection = Inspection<Self>()

    var body: some View {
      VStack {
        QueryView()
          .environment(\.queryClient, self.client)
        Button("Reset Client") {
          self.client = QueryClient()
        }
      }
      .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }
  }

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
        let _ = print("Status", self.query.status)
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
      .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }
  }
#endif
