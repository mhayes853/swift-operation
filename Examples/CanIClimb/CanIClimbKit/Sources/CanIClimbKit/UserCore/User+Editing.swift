import Dependencies
import Foundation
import SharingOperation
import SwiftNavigation

// MARK: - Edit

extension User {
  public struct Edit: Hashable, Sendable, Codable {
    public var name: User.Name
    public var subtitle: String

    public init(name: User.Name, subtitle: String) {
      self.name = name
      self.subtitle = subtitle
    }
  }
}

// MARK: - Mutation

extension User {
  public struct EditArguments: Sendable {
    let edit: User.Edit

    public init(edit: User.Edit) {
      self.edit = edit
    }
  }

  public static var editMutation: some MutationRequest<EditArguments, User, any Error> {
    Self.$editMutation.alerts(success: .editProfileSuccess, failure: .editProfileFailure)
  }

  @MutationRequest
  private static func editMutation(arguments: EditArguments) async throws -> User {
    @Dependency(\.defaultOperationClient) var client
    @Dependency(User.CurrentUserKey.self) var users

    let user = try await users.edit(with: arguments.edit)
    client.store(for: User.$currentStatusQuery).currentValue = .user(user)
    return user
  }
}

// MARK: - AlertState

extension AlertState where Action == Never {
  public static let editProfileSuccess = Self {
    TextState("Success")
  } message: {
    TextState("Your profile has been updated.")
  }

  public static let editProfileFailure = Self.remoteOperationError {
    TextState("Failed to Edit Your Profile")
  } message: {
    TextState("Your profile could not be edited. Please try again later.")
  }
}
