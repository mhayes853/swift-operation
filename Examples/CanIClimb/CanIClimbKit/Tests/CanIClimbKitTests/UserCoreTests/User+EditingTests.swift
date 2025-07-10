import CanIClimbKit
import CustomDump
import DependenciesTestSupport
import Foundation
import SharingGRDB
import SharingQuery
import Synchronization
import Testing

extension DependenciesTestSuite {
  @Suite("User+Editing tests")
  struct UserEditingTests {
    @MainActor
    @Test("Editing User Updates Current User")
    func editUser() async throws {
      @Dependency(\.defaultDatabase) var database

      var editedUser = User.mock2
      editedUser.subtitle = "Edited"

      let editor = User.MockEditor(result: .success(editedUser))
      let currentUser = CurrentUser(database: database)

      try await withDependencies {
        $0[User.EditorKey.self] = editor
        $0[CurrentUser.self] = currentUser
      } operation: {
        @Dependency(\.defaultQueryClient) var client
        let userStore = client.store(for: User.currentQuery)
        let editStore = client.store(for: User.editMutation)

        let edit = User.Edit(name: editedUser.name, subtitle: editedUser.subtitle)
        try await editStore.mutate(with: User.EditMutation.Arguments(edit: edit))

        expectNoDifference(userStore.currentValue, editedUser)

        let localUser = try await currentUser.localUser()
        expectNoDifference(localUser, editedUser)
      }
    }
  }
}
