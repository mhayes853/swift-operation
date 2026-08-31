import CanIClimbKit
import CustomDump
import Foundation
import GRDB
import Operation
import Synchronization
import Testing

@Suite("CurrentUser tests")
struct CurrentUserTests {
  private let database = try! canIClimbDatabase(isTracingEnabled: false)

  @Test("Caches Current User When Loaded")
  func cachesCurrentUserWhenLoaded() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: DummyBackend(scenario: DummyBackend.Scenario())
    )
    let currentUser = CurrentUser(database: self.database, api: api)
    try await currentUser.signIn(with: .mock1)
    let status = try await currentUser.currentStatus()
    let localUser = try await currentUser.localUser()

    expectNoDifference(localUser, User.mock1)
    expectNoDifference(status, .user(try #require(localUser)))
  }

  @Test("Removes Current Local User From Cache When Account Deletion Successful")
  func removesCurrentUserFromCacheWhenAccountDeletionSuccessful() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: DummyBackend(scenario: DummyBackend.Scenario())
    )

    let currentUser = CurrentUser(database: database, api: api)
    try await currentUser.signIn(with: .mock1)
    _ = try await currentUser.currentStatus()
    try await currentUser.delete()
    let localUser = try await currentUser.localUser()

    expectNoDifference(localUser, nil)
  }

  @Test("Removes Current Local User From Cache When Sign Out Successful")
  func setsCurrentUserToNilWhenSignOutSuccessful() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: DummyBackend(scenario: DummyBackend.Scenario())
    )

    let currentUser = CurrentUser(database: database, api: api)
    try await currentUser.signIn(with: .mock1)
    _ = try await currentUser.currentStatus()
    try await currentUser.signOut()
    let localUser = try await currentUser.localUser()

    expectNoDifference(localUser, nil)
  }

  @Test("Editing Current User Updates Cached User")
  func editUser() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: DummyBackend(
        scenario: DummyBackend.Scenario(),
        responseOverride: { request in
          guard request.url?.path() == "/user", request.httpMethod == "PATCH" else { return nil }
          return DummyBackend.Response.json(User.mock2)
        }
      )
    )

    let currentUser = CurrentUser(database: database, api: api)
    try await currentUser.signIn(with: .mock1)
    _ = try await currentUser.currentStatus()
    let editedUser = try await currentUser.edit(
      with: User.Edit(name: User.mock2.name, subtitle: User.mock2.subtitle)
    )
    let localUser = try await currentUser.localUser()

    expectNoDifference(localUser, .mock2)
    expectNoDifference(editedUser, localUser)
  }

  @Test("Current Status Is Unauthorized When API 401s")
  func currentStatusIsUnauthorizedWhenAPI401s() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: DummyBackend(
        scenario: DummyBackend.Scenario(),
        responseOverride: { request in
          switch request.url?.path() {
          case "/user", "/auth/refresh": DummyBackend.Response(statusCode: 401)
          default: nil
          }
        }
      )
    )
    let currentUser = CurrentUser(database: database, api: api)
    try await currentUser.signIn(with: .mock1)
    let status = try await currentUser.currentStatus()
    expectNoDifference(status, .unauthorized)
  }

  @Test("Doesn't Attempt API Request For Current Status When User Never Signed In")
  func doesntAttemptAPIRequestForCurrentStatusWhenUserNeverSignedIn() async throws {
    let callCount = Mutex(0)
    let api = CanIClimbAPI.testInstance(
      transport: MockHTTPDataTransport { _ in
        callCount.withLock { $0 += 1 }
        return (401, .empty)
      }
    )
    let currentUser = CurrentUser(database: database, api: api)
    let status = try await currentUser.currentStatus()
    expectNoDifference(status, .unauthorized)
    callCount.withLock { expectNoDifference($0, 0) }
  }
}
