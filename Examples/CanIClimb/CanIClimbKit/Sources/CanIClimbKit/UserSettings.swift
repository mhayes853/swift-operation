import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - UserSettingsModel

@MainActor
@Observable
public final class UserSettingsModel {
  public var editableFields: EditableFields
  private var originalEditableFields: EditableFields

  public var destination: Destination?

  @ObservationIgnored
  @SharedQuery(User.signOutMutation) private var signOut: Void?

  @ObservationIgnored
  @SharedQuery(User.deleteMutation) private var deleteAccount: Void?

  @ObservationIgnored
  @SharedQuery(User.editMutation) private var editProfile

  @ObservationIgnored public var onSignOut: ((SignOutType) -> Void)?
  @ObservationIgnored public var onLoading: (() -> Void)?

  public init(user: User) {
    self.editableFields = EditableFields(user: user)
    self.originalEditableFields = EditableFields(user: user)
  }
}

extension UserSettingsModel {
  public enum LoadingType: Hashable, Sendable {
    case signOut
    case accountDeleted
    case editProfile
  }

  public var loadingType: LoadingType? {
    if self.$editProfile.isLoading {
      .editProfile
    } else if self.$deleteAccount.isLoading {
      .accountDeleted
    } else if self.$signOut.isLoading {
      .signOut
    } else {
      nil
    }
  }
}

extension UserSettingsModel {
  public var submittableEdit: User.Edit? {
    guard !self.editableFields.name.isEmpty && self.editableFields != self.originalEditableFields
    else { return nil }
    if let components = try? PersonNameComponents(self.editableFields.name) {
      return User.Edit(name: components, subtitle: self.editableFields.subtitle)
    }
    var components = PersonNameComponents()
    components.givenName = self.editableFields.name
    return User.Edit(name: components, subtitle: self.editableFields.subtitle)
  }

  public func editSubmitted(edit: User.Edit) async {
    do {
      let task = self.$editProfile.mutateTask(with: User.EditMutation.Arguments(edit: edit))
      self.onLoading?()
      let user = try await task.runIfNeeded()
      self.originalEditableFields = EditableFields(user: user)
      self.destination = .alert(.editProfileSuccess)
    } catch {
      self.destination = .alert(.editProfileFailure)
    }
  }
}

extension UserSettingsModel {
  public func deleteAccountInvoked() {
    self.destination = .alert(.confirmAccountDeletion)
  }
}

extension UserSettingsModel {
  public func signOutInvoked() async {
    do {
      let task = self.$signOut.mutateTask()
      self.onLoading?()
      try await task.runIfNeeded()
      self.destination = .alert(.signOutSuccess(type: .signOut))
      self.onSignOut?(.signOut)
    } catch {
      self.destination = .alert(.signOutFailure(type: .signOut))
    }
  }
}

extension UserSettingsModel {
  public func alert(action: AlertAction?) async {
    switch action {
    case .accountDeletionConfirmed:
      await self.deleteAccount()
    default:
      break
    }
  }

  private func deleteAccount() async {
    do {
      let task = self.$deleteAccount.mutateTask()
      self.onLoading?()
      try await task.runIfNeeded()
      self.destination = .alert(.signOutSuccess(type: .accountDeleted))
      self.onSignOut?(.accountDeleted)
    } catch {
      self.destination = .alert(.signOutFailure(type: .accountDeleted))
    }
  }
}

extension UserSettingsModel {
  public enum SignOutType: Hashable, Sendable {
    case signOut
    case accountDeleted
  }
}

extension UserSettingsModel {
  public struct EditableFields: Hashable, Sendable {
    public var name: String
    public var subtitle: String

    fileprivate init(user: User) {
      self.name = user.name.formatted()
      self.subtitle = user.subtitle
    }
  }
}

extension UserSettingsModel {
  @CasePathable
  public enum Destination: Hashable, Sendable {
    case alert(AlertState<AlertAction>)
  }
}

// MARK: - AlertState

extension UserSettingsModel {
  public enum AlertAction: Hashable, Sendable {
    case accountDeletionConfirmed
  }
}

extension AlertState where Action == UserSettingsModel.AlertAction {
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

  public static let confirmAccountDeletion = Self {
    TextState("Confirm Account Deletion")
  } actions: {
    ButtonState(role: .cancel) {
      TextState("Cancel")
    }
    ButtonState(role: .destructive, action: .accountDeletionConfirmed) {
      TextState("Delete Account")
    }
  } message: {
    TextState("Are you sure you want to delete your account? You cannot undo this action.")
  }

  public static func signOutSuccess(type: UserSettingsModel.SignOutType) -> Self {
    Self {
      switch type {
      case .signOut: TextState("Signed Out Successfully")
      case .accountDeleted: TextState("Your Account Has Been Deleted")
      }
    } message: {
      switch type {
      case .signOut: TextState("You have successfully signed out.")
      case .accountDeleted: TextState("Your account has been successfully deleted.")
      }
    }
  }

  public static func signOutFailure(type: UserSettingsModel.SignOutType) -> Self {
    Self.remoteOperationError {
      switch type {
      case .signOut: TextState("Failed to Sign Out")
      case .accountDeleted: TextState("Failed to Delete Account")
      }
    } message: {
      switch type {
      case .signOut: TextState("An error occurred while signing out. Please try again later.")
      case .accountDeleted: TextState("Your account could not be deleted. Please try again later.")
      }
    }
  }
}

// MARK: - UserSettingsView

public struct UserSettingsView: View {
  @Bindable var model: UserSettingsModel

  public var body: some View {
    Form {

    }
    .navigationTitle("Profile")
    .alert(self.$model.destination.alert) { action in
      Task { await self.model.alert(action: action) }
    }
  }
}
