import CanIClimbKit
import Foundation
import Operation

extension CanIClimbAPI {
  static func testInstance(
    transport: any HTTPDataTransport,
    secureStorage: InMemorySecureStorage = InMemorySecureStorage(),
    isAuthenticated: Bool = false
  ) -> CanIClimbAPI {
    if isAuthenticated {
      secureStorage["canIClimbAPI_RefreshToken"] = Data("refresh".utf8)
    }
    return CanIClimbAPI(
      transport: transport,
      tokens: CanIClimbAPI.Tokens(client: OperationClient(), secureStorage: secureStorage)
    )
  }
}
