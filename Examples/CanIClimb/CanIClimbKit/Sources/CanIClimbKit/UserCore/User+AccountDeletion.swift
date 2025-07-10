import Dependencies
import Query

// MARK: - AccountDeletor

extension User {
  public protocol AccountDeleter: Sendable {
    func deleteUser() async throws
  }

  public enum AccountDeleterKey: DependencyKey {
    public static let liveValue: any User.AccountDeleter = CanIClimbAPI.shared
  }
}

extension CanIClimbAPI: User.AccountDeleter {}

extension User {
  @MainActor
  public final class MockAccountDeleter: AccountDeleter {
    public private(set) var deleteCount = 0

    public init() {}

    public func deleteUser() async throws {
      self.deleteCount += 1
    }
  }
}

// MARK: - Mutation

extension User {
  public static let deleteMutation = DeleteMutation()

  public struct DeleteMutation: MutationRequest, Hashable {
    public func mutate(
      with arguments: Void,
      in context: QueryContext,
      with continuation: QueryContinuation<Void>
    ) async throws {
      @Dependency(\.defaultQueryClient) var client
      @Dependency(User.AccountDeleterKey.self) var deleter
      @Dependency(CurrentUser.self) var currentUser

      try await currentUser.delete(using: deleter)
      client.store(for: User.currentQuery).currentValue = nil
    }
  }
}
