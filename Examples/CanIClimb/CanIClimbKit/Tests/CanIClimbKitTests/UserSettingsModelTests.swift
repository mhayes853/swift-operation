import CanIClimbKit
import CustomDump
import Dependencies
import Foundation
import SharingOperation
import SwiftNavigation
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("UserSettingsModel tests")
  struct UserSettingsModelTests {
    @Test("Not Editable Initially")
    func notEditableInitially() {
      let model = UserSettingsModel(user: .mock1)
      expectNoDifference(model.submittableEdit, nil)
    }

    @Test("Not Editable When Name Empty")
    func notEditableWhenNameEmpty() {
      let model = UserSettingsModel(user: .mock1)
      model.editableFields.name = ""
      expectNoDifference(model.submittableEdit, nil)
    }

    @Test("Editable When Fields Changed")
    func editableWhenFieldsChanged() {
      let model = UserSettingsModel(user: .mock1)
      model.editableFields.name = "New Name"
      expectNoDifference(model.submittableEdit != nil, true)
    }

    @Test("Editable With Numerical Name")
    func editableWithNumericalName() {
      let model = UserSettingsModel(user: .mock1)
      model.editableFields.name = "123"
      expectNoDifference(model.submittableEdit != nil, true)
    }

    @Test("Cannot Submit Editable Fields After Editing User")
    func cannotSubmitEditableFieldsAfterEditingUser() async throws {
      try await withDefaultEdit { model in
        try await model.editSubmitted(edit: #require(model.submittableEdit))
        expectNoDifference(model.submittableEdit, nil)
      }
    }

    @Test("Loading Type Is Editing When Edit Submitted")
    func loadingTypeIsEditingWhenEditSubmitted() async throws {
      try await withDefaultEdit { model in
        var loadingType: UserSettingsModel.LoadingType?
        model.onLoading = { loadingType = $0 }

        try await model.editSubmitted(edit: #require(model.submittableEdit))
        expectNoDifference(loadingType, .editProfile)
      }
    }

    @Test("Successful Delete Account Flow")
    func successfulDeleteAccountFlow() async throws {
      try await withDependencies {
        $0[User.AccountDeleterKey.self] = User.MockAccountDeleter()
      } operation: {
        let model = UserSettingsModel(user: .mock1)
        var signOutCount = 0
        model.onSignOut = { _ in signOutCount += 1 }

        model.deleteAccountInvoked()
        expectNoDifference(model.destination, .alert(.confirmAccountDeletion))

        model.destination = nil
        try await model.alert(action: .accountDeletionConfirmed)
        expectNoDifference(signOutCount, 1)
      }
    }

    @Test("Unsuccessful Delete Account Flow")
    func unsuccessfulDeleteAccountFlow() async throws {
      await withDependencies {
        struct SomeError: Error {}
        let deleter = User.MockAccountDeleter()
        deleter.error = SomeError()
        $0[User.AccountDeleterKey.self] = deleter
      } operation: {
        let model = UserSettingsModel(user: .mock1)
        var signOutCount = 0
        model.onSignOut = { _ in signOutCount += 1 }

        model.deleteAccountInvoked()
        expectNoDifference(model.destination, .alert(.confirmAccountDeletion))

        model.destination = nil
        try? await model.alert(action: .accountDeletionConfirmed)
        expectNoDifference(signOutCount, 0)
      }
    }

    @Test("Loading Type Is AccountDeletion When Deleting Account")
    func loadingTypeIsAccountDeletionWhenDeletingAccount() async throws {
      try await withDependencies {
        $0[User.AccountDeleterKey.self] = User.MockAccountDeleter()
      } operation: {
        let model = UserSettingsModel(user: .mock1)

        model.deleteAccountInvoked()
        expectNoDifference(model.destination, .alert(.confirmAccountDeletion))
        model.destination = nil

        var loadingType: UserSettingsModel.LoadingType?
        model.onLoading = { loadingType = $0 }

        try await model.alert(action: .accountDeletionConfirmed)
        expectNoDifference(loadingType, .accountDeleted)
      }
    }

    @Test("Successful Sign Out Flow")
    func successfulSignOutFlow() async throws {
      try await withDependencies {
        $0[User.AuthenticatorKey.self] = User.MockAuthenticator()
      } operation: {
        let model = UserSettingsModel(user: .mock1)
        var signOutCount = 0
        model.onSignOut = { _ in signOutCount += 1 }

        try await model.signOutInvoked()
        expectNoDifference(signOutCount, 1)
      }
    }

    @Test("Unsuccessful Sign Out Flow")
    func unsuccessfulSignOutFlow() async throws {
      await withDependencies {
        struct SomeError: Error {}
        let authenticator = User.MockAuthenticator()
        authenticator.signOutError = SomeError()
        $0[User.AuthenticatorKey.self] = authenticator
      } operation: {
        let model = UserSettingsModel(user: .mock1)
        var signOutCount = 0
        model.onSignOut = { _ in signOutCount += 1 }

        try? await model.signOutInvoked()
        expectNoDifference(signOutCount, 0)
      }
    }

    @Test("Loading Type Is SignOut When Signing Out")
    func loadingTypeIsSignOutWhenSigningOut() async throws {
      try await withDependencies {
        $0[User.AuthenticatorKey.self] = User.MockAuthenticator()
      } operation: {
        let model = UserSettingsModel(user: .mock1)
        var loadingType: UserSettingsModel.LoadingType?
        model.onLoading = { loadingType = $0 }

        try await model.signOutInvoked()
        expectNoDifference(loadingType, .signOut)
      }
    }
  }
}

@MainActor
private func withDefaultEdit(
  result: Result<User, any Error>? = nil,
  _ fn: (UserSettingsModel) async throws -> Void
) async throws {
  var editedUser = User.mock1
  editedUser.subtitle = "Edited"

  try await withDependencies {
    struct SomeError: Error {}
    if let result = result {
      $0[User.EditorKey.self] = User.MockEditor(result: result)
    } else {
      $0[User.EditorKey.self] = User.MockEditor(result: .success(editedUser))
    }
  } operation: {
    let model = UserSettingsModel(user: .mock1)
    model.editableFields.subtitle = editedUser.subtitle
    try await fn(model)
  }
}
