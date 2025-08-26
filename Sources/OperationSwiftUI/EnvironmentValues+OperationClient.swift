#if canImport(SwiftUI)
  import SwiftUI

  // MARK: - OperationClient Modifier

  extension View {
    /// Sets the ``OperationClient`` for this view.
    ///
    /// - Parameter client: The client to use for this view.
    /// - Returns: Some view
    public func operationClient(_ client: OperationClient) -> some View {
      self.environment(\.operationClient, client)
    }
  }

  // MARK: - EnvironmentValues

  extension EnvironmentValues {
    /// The current ``OperationClient`` in this environment.
    public var operationClient: OperationClient {
      get { self[OperationClientKey.self] }
      set { self[OperationClientKey.self] = newValue }
    }

    private enum OperationClientKey: EnvironmentKey {
      static let defaultValue = OperationClient()
    }
  }
#endif
