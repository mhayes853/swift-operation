import Dependencies
import Observation
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - UserSettingsModel

@MainActor
@Observable
public final class UserSettingsModel: HashableObject {
  public var editableFields: EditableFields
  private var originalEditableFields: EditableFields

  public var destination: Destination?

  @ObservationIgnored
  @SharedQuery(User.signOutMutation, animation: .bouncy) private var signOut: Void?

  @ObservationIgnored
  @SharedQuery(User.deleteMutation, animation: .bouncy) private var deleteAccount: Void?

  @ObservationIgnored
  @SharedQuery(User.editMutation, animation: .bouncy) private var editProfile

  @ObservationIgnored public var onSignOut: ((SignOutType) -> Void)?
  @ObservationIgnored public var onLoading: ((LoadingType) -> Void)?

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

  public func editSubmitted(edit: User.Edit) async throws {
    let task = self.$editProfile.mutateTask(with: User.EditMutation.Arguments(edit: edit))
    self.indicateLoading()
    let user = try await task.runIfNeeded()
    self.originalEditableFields = EditableFields(user: user)
  }
}

extension UserSettingsModel {
  public func deleteAccountInvoked() {
    self.destination = .alert(.confirmAccountDeletion)
  }
}

extension UserSettingsModel {
  public func signOutInvoked() async throws {
    let task = self.$signOut.mutateTask()
    self.indicateLoading()
    try await task.runIfNeeded()
    self.onSignOut?(.signOut)
  }
}

extension UserSettingsModel {
  public func alert(action: AlertAction?) async throws {
    switch action {
    case .accountDeletionConfirmed:
      try await self.deleteAccount()
    default:
      break
    }
  }

  private func deleteAccount() async throws {
    let task = self.$deleteAccount.mutateTask()
    self.indicateLoading()
    try await task.runIfNeeded()
    self.onSignOut?(.accountDeleted)
  }
}

extension UserSettingsModel {
  private func indicateLoading() {
    guard let loadingType else { return }
    self.onLoading?(loadingType)
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
}

// MARK: - UserSettingsView

public struct UserSettingsView: View {
  @Bindable var model: UserSettingsModel

  public var body: some View {
    Form {
      if let loadingType = self.model.loadingType {
        LoadingIndicatorSectionView(loadingType: loadingType)
      }
      Group {
        EditableSectionView(model: self.model)
        ManageAccountSectionView(model: self.model)
      }
      .disabled(self.model.loadingType != nil)
    }
    .navigationTitle("Your Account")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .alert(self.$model.destination.alert) { action in
      Task { try await self.model.alert(action: action) }
    }
  }
}

private struct LoadingIndicatorSectionView: View {
  let loadingType: UserSettingsModel.LoadingType

  var body: some View {
    Section {
      Label {
        Group {
          switch self.loadingType {
          case .accountDeleted: Text("Deleting Account")
          case .editProfile: Text("Updating Profile")
          case .signOut: Text("Signing Out")
          }
        }
        .bold()
      } icon: {
        SpinnerView()
      }
    }
  }
}

private struct EditableSectionView: View {
  @Bindable var model: UserSettingsModel

  var body: some View {
    Section {
      TextField("Name", text: self.$model.editableFields.name.animation())
      TextField("Subtitle", text: self.$model.editableFields.subtitle.animation())
    } header: {
      Text("Profile Info")
    }

    if let submittableEdit = self.model.submittableEdit {
      Button("Save Profile", systemImage: "square.and.arrow.down") {
        Task { try await self.model.editSubmitted(edit: submittableEdit) }
      }
    }
  }
}

private struct ManageAccountSectionView: View {
  let model: UserSettingsModel

  var body: some View {
    Section {
      Button("Sign Out", systemImage: "person.crop.circle", role: .destructive) {
        Task { try await self.model.signOutInvoked() }
      }
      Button("Delete Account", systemImage: "trash.slash", role: .destructive) {
        self.model.deleteAccountInvoked()
      }
    } header: {
      Text("Manage Account")
    }
  }
}

#Preview {
  @Previewable @State var isPresented = true

  let _ = prepareDependencies {
    $0.defaultDatabase = try! canIClimbDatabase()
    $0.defaultQueryClient = QueryClient(storeCreator: .canIClimb)

    $0[User.AuthenticatorKey.self] = User.MockAuthenticator()
    $0[User.AccountDeleterKey.self] = User.MockAccountDeleter()
    $0[User.EditorKey.self] = User.PassthroughEditor()
  }

  Button("Present Settings") {
    isPresented = true
  }
  .sheet(isPresented: $isPresented) {
    NavigationStack {
      UserSettingsView(model: UserSettingsModel(user: .mock1))
        .dismissable()
    }
  }
  .observeQueryAlerts()
}
