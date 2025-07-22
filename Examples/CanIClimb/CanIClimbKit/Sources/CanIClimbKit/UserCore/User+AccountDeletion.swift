import Dependencies
import Query
import SwiftNavigation

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
    public var error: (any Error)?

    public init() {}

    public func deleteUser() async throws {
      if let error = error {
        throw error
      }
      self.deleteCount += 1
    }
  }
}

// MARK: - Mutation

extension User {
  public static let deleteMutation = DeleteMutation()
    .alerts(success: .deleteAccountSuccess, failure: .deleteAccountFailure)

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
      let userStore = client.store(for: User.currentQuery)
      userStore.withExclusiveAccess {
        userStore.currentValue = nil
        userStore.setResult(to: .failure(User.UnauthorizedError()))
      }
    }
  }
}

// MARK: - AlertState

extension AlertState where Action == Never {
  public static let deleteAccountSuccess = Self {
    TextState("Your Account Has Been Deleted")
  } message: {
    TextState(
      """
      Your account has been successfully deleted. You can create a new account by signing in with \
      your Apple ID.
      """
    )
  }

  public static let deleteAccountFailure = Self.remoteOperationError {
    TextState("Failed to Delete Account")
  } message: {
    TextState("Your account could not be deleted. Please try again later.")
  }
}
