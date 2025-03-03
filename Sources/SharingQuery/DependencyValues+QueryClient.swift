import Dependencies
import QueryCore

extension DependencyValues {
  public var queryClient: QueryClient {
    get { self[QueryClientKey.self] }
    set { self[QueryClientKey.self] = newValue }
  }

  private enum QueryClientKey: DependencyKey {
    static var liveValue: QueryClient {
      QueryClient()
    }

    // TODO: - Test Configuration

    static var testValue: QueryClient {
      QueryClient()
    }
  }
}
