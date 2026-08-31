import CasePaths
import Dependencies
import SharingOperation

// MARK: - Current Status

extension User {
  @CasePathable
  public enum CurrentStatus: Hashable, Sendable {
    case user(User)
    case unauthorized
  }
}

// MARK: - Query

extension User {
  @QueryRequest
  public static func currentStatusQuery(
    continuation: OperationContinuation<CurrentStatus, any Error>
  ) async throws -> CurrentStatus {
    let users = Dependency(User.CurrentUserKey.self).wrappedValue

    async let status = users.currentStatus()
    if let localUser = try await users.localUser() {
      continuation.yield(.user(localUser))
    }
    return try await status
  }
}
