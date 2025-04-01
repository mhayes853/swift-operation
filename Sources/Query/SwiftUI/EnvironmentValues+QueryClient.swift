#if canImport(SwiftUI)
  import SwiftUI

  // MARK: - QueryClient Modifier

  extension View {
    public func queryClient(_ client: QueryClient) -> some View {
      self.environment(\.queryClient, client)
    }
  }

  // MARK: - EnvironmentValues

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
