import FoundationModels
import Operation

public struct UserLocationTool: Tool {
  public let name = "userLocation"
  public let description =
    "Provides the user's current location as a latitude and longitude coordinate."

  @Generable
  public struct Arguments: Sendable {}

  @Generable
  public enum Output: Hashable, Sendable {
    case permissionDenied
    case reading(LocationReadingGenerable)
  }

  private let client: OperationClient

  public init(client: OperationClient) {
    self.client = client
  }

  public func call(arguments: Arguments) async throws -> Output {
    do {
      let store = self.client.store(for: LocationReading.userQuery)
      return .reading(LocationReadingGenerable(reading: try await store.fetch()))
    } catch is UserLocationUnauthorizedError {
      return .permissionDenied
    }
  }
}
