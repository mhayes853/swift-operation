#if canImport(SwiftUI)
  import SwiftUI

  extension EnvironmentValues {
    public var queryClient: QueryClient {
      get { self[QueryClientKey.self] }
      set { self[QueryClientKey.self] = newValue }
    }

    private enum QueryClientKey: EnvironmentKey {
      static let defaultValue = QueryClient()
    }
  }
#endif
