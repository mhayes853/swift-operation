#if canImport(SwiftUI)
  import SwiftUI

  // MARK: - QueryClient Modifier

  extension View {
    /// Sets the ``QueryClient`` for this view.
    ///
    /// - Parameter client: The client to use for this view.
    /// - Returns: Some view
    public func queryClient(_ client: QueryClient) -> some View {
      self.environment(\.queryClient, client)
    }
  }

  // MARK: - EnvironmentValues

  extension EnvironmentValues {
    /// The current ``QueryClient`` in this environment.
    public var queryClient: QueryClient {
      get { self[QueryClientKey.self] }
      set { self[QueryClientKey.self] = newValue }
    }

    private enum QueryClientKey: EnvironmentKey {
      static let defaultValue = QueryClient.shared
    }
  }
#endif
