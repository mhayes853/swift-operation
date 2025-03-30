#if canImport(SwiftUI)
  import SwiftUI
  import ViewInspector
  import Testing
  import QuerySwiftUI
  import _TestQueries
  import CustomDump

  @MainActor
  @Suite("State+Query tests", .serialized)
  struct StateQueryTests {
    init() {
      StateQuery.action.withLock { $0 = .load }
    }

    @Test("Idle By Default")
    func idleByDefault() throws {
      let view = TestView()
      ViewHosting.host(view: view)
      defer { ViewHosting.expel() }
      let state = try view.inspect().find(text: "Idle").string()
      expectNoDifference(state, "Idle")
    }
  }

  private struct StateQuery: QueryRequest, Hashable {
    enum Action {
      case load, suspend, fail
    }

    static let action = Lock(Action.load)

    static let successValue = "Success"

    typealias Value = String

    struct SomeError: Error {
      var localizedDescription: String {
        "Some Error"
      }
    }

    func fetch(
      in context: QueryCore.QueryContext,
      with continuation: QueryCore.QueryContinuation<Value>
    ) async throws -> Value {
      let task = Self.action.withLock { action in
        switch action {
        case .load:
          return Task { () async throws -> String in
            return Self.successValue
          }
        case .suspend:
          return Task {
            try await Task.never()
            throw SomeError()
          }
        case .fail:
          return Task { throw SomeError() }
        }
      }
      return try await task.value
    }
  }

  private struct TestView: View {
    @State.Query(query: StateQuery().enableAutomaticFetching(when: .always(false)))
    private var query: StateQuery.State

    var body: some View {
      VStack {
        switch self.query.status {
        case .idle:
          Text("Idle")
        case .loading:
          Text("Loading")
        case let .result(.success(data)):
          Text("Success: \(data)")
        case let .result(.failure(error)):
          Text("Failure: \(error.localizedDescription)")
        }

        Button("Fetch") {
          Task { try await self.$query.fetch() }
        }
      }
    }
  }
#endif
