#if canImport(SwiftUI)
  import SwiftUI
  import ViewInspector
  import Testing
  import QuerySwiftUI
  import _TestQueries
  import CustomDump
  import Combine

  @MainActor
  @Suite("State+Query tests", .serialized)
  final class StateQueryTests {
    init() {
      StateQuery.action.withLock { $0 = .load }
    }

    @Test("Idle By Default")
    func idleByDefault() throws {
      let view = TestView()
      ViewHosting.host(view: view)
      defer { ViewHosting.expel() }

      #expect(throws: Never.self) {
        try view.inspect().find(text: "Idle")
      }
    }

    @Test("Is Loading")
    func isLoading() async throws {
      StateQuery.action.withLock { $0 = .suspend }
      let view = TestView()
      ViewHosting.host(view: view)
      defer { ViewHosting.expel() }

      try await view.inspection.inspect { try $0.find(button: "Fetch").tap() }
      view.inspection.inspect(after: 0.1) { view in
        #expect(throws: Never.self) {
          try view.find(text: "Loading")
        }
      }
    }

    @Test("Success")
    func success() async throws {
      StateQuery.action.withLock { $0 = .load }
      let view = TestView()
      ViewHosting.host(view: view)
      defer { ViewHosting.expel() }

      try await view.inspection.inspect { try $0.find(button: "Fetch").tap() }
      view.inspection.inspect(after: 0.1) { view in
        #expect(throws: Never.self) {
          try view.find(text: "Success: \(StateQuery.successValue)")
        }
      }
    }

    @Test("Failure")
    func failure() async throws {
      StateQuery.action.withLock { $0 = .fail }
      let view = TestView()
      ViewHosting.host(view: view)
      defer { ViewHosting.expel() }

      try await view.inspection.inspect { try $0.find(button: "Fetch").tap() }
      view.inspection.inspect(after: 0.1) { view in
        #expect(throws: Never.self) {
          try view.find(text: "Failure: \(StateQuery.SomeError().localizedDescription)")
        }
      }
    }
  }

  extension QueryClient {
    fileprivate static let shared = QueryClient()
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

    let inspection = Inspection<Self>()

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
      .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }
  }

  // MARK: - Inspection

  @MainActor
  final class Inspection<V> {
    let notice = PassthroughSubject<UInt, Never>()
    var callbacks = [UInt: (V) -> Void]()

    func visit(_ view: V, _ line: UInt) {
      if let callback = callbacks.removeValue(forKey: line) {
        callback(view)
      }
    }
  }

  extension Inspection: InspectionEmissary {}
#endif
