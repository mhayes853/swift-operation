import CanIClimbKit
import Operation

extension CanIClimbAPI {
  static func testInstance(
    transport: any CanIClimbAPI.DataTransport,
    secureStorage: InMemorySecureStorage = InMemorySecureStorage()
  ) -> CanIClimbAPI {
    CanIClimbAPI(
      transport: transport,
      tokens: CanIClimbAPI.Tokens(client: QueryClient(), secureStorage: secureStorage)
    )
  }
}
