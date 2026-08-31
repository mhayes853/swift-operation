import Dependencies
import Operation
import SwiftNavigation

// MARK: - Mutation

extension User {
  public static var deleteMutation: some MutationRequest<Void, Void, any Error> {
    Self.$deleteMutation
      .alerts(success: .deleteAccountSuccess, failure: .deleteAccountFailure)
  }

  @MutationRequest
  private static func deleteMutation() async throws {
    @Dependency(\.defaultOperationClient) var client
    @Dependency(User.CurrentUserKey.self) var users

    try await users.delete()

    let userStore = client.store(for: User.$currentStatusQuery)
    userStore.resetState()
    userStore.currentValue = .unauthorized
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
