import CanIClimbKit
import CustomDump
import DependenciesTestSupport
import Foundation
import SharingGRDB
import SharingQuery
import Synchronization
import Testing

@Suite("User+Auth tests", .dependency(\.defaultDatabase, try! canIClimbDatabase()))
struct UserAuthTests {
  @MainActor
  @Test("Loads Current User When Signed In")
  func loadsCurrentUserWhenSignedIn() async throws {
    let authenticator = User.MockAuthenticator()
    try await withDependencies {
      $0[User.CurrentLoaderKey.self] = User.MockCurrentLoader(result: .success(.mock1))
      $0[User.AuthenticatorKey.self] = authenticator
    } operation: {
      @Dependency(\.defaultQueryClient) var client
      let signInStore = client.store(for: User.signInMutation)
      let userStore = client.store(for: User.currentQuery)

      let credentials = User.SignInCredentials(
        userId: User.mock1.id,
        name: User.mock1.name,
        token: Data()
      )
      authenticator.requiredCredentials = credentials
      try await signInStore.mutate(with: User.SignInMutation.Arguments(credentials: credentials))

      let task = try #require(userStore.activeTasks.first)
      let user = try await task.runIfNeeded()
      expectNoDifference(user, .mock1)
    }
  }
}
