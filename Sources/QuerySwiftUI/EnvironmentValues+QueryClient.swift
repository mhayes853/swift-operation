#if canImport(SwiftUI)
  import QueryCore
  import SwiftUI

  extension EnvironmentValues {
    @Entry public var queryClient = QueryClient()
  }
#endif
