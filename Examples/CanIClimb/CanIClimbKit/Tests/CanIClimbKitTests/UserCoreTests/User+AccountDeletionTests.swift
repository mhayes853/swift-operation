import CanIClimbKit
import CustomDump
import DependenciesTestSupport
import Foundation
import SharingGRDB
import SharingQuery
import Synchronization
import Testing

extension DependenciesTestSuite {
  @MainActor
  @Suite("User+AccountDeletion tests")
  struct UserAccountDeletionTests {
    @Test("Sets Current User to Nil When Deletion Successful")
    func setsCurrentUserToNilWhenDeletionSuccessful() async throws {
      @Dependency(\.defaultDatabase) var database

      let deleter = User.MockAccountDeleter()
      let userStorage = CurrentUser(database: database)
      try await withDependencies {
        $0[CurrentUser.self] = userStorage
        $0[User.CurrentLoaderKey.self] = User.MockCurrentLoader(result: .success(.mock1))
        $0[User.AccountDeleterKey.self] = deleter
      } operation: {
        @Dependency(\.defaultQueryClient) var client
        let userStore = client.store(for: User.currentQuery)
        let deleteStore = client.store(for: User.deleteMutation)

        try await userStore.fetch()

        expectNoDifference(deleter.deleteCount, 0)
        expectNoDifference(userStore.currentValue, .mock1)
        try await deleteStore.mutate()
        expectNoDifference(deleter.deleteCount, 1)
        expectNoDifference(userStore.currentValue, nil)
        expectNoDifference(userStore.error is User.UnauthorizedError, true)

        let localUser = try await userStorage.localUser()
        expectNoDifference(localUser, nil)
      }
    }
  }
}
