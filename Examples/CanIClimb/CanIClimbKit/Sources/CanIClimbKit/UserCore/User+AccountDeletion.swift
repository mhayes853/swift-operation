import Dependencies
import Operation
import SwiftNavigation

// MARK: - AccountDeletor

extension User {
  public protocol AccountDeleter: Sendable {
    func delete() async throws
  }

  public enum AccountDeleterKey: DependencyKey {
    public static var liveValue: any User.AccountDeleter {
      CurrentUser.shared
    }
  }
}

extension User {
  @MainActor
  public final class MockAccountDeleter: AccountDeleter {
    public private(set) var deleteCount = 0
    public var error: (any Error)?

    public init() {}

    public func delete() async throws {
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
      in context: OperationContext,
      with continuation: OperationContinuation<Void>
    ) async throws {
      @Dependency(\.defaultOperationClient) var client
      @Dependency(User.AccountDeleterKey.self) var deleter

      try await deleter.delete()
      let userStore = client.store(for: User.currentQuery)
      userStore.withExclusiveAccess {
        $0.currentValue = nil
        $0.setResult(to: .failure(User.UnauthorizedError()))
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
