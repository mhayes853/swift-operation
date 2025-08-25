import CanIClimbKit
import CustomDump
import Foundation
import GRDB
import Operation
import Testing

@Suite("CurrentUser tests")
struct CurrentUserTests {
  private let database = try! canIClimbDatabase()

  @Test("Caches Current User When Loaded")
  func cachesCurrentUserWhenLoaded() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: .mock { request, _ in
        switch request {
        case .currentUser:
          (200, .json(User.mock1))
        default:
          (400, .data(Data()))
        }
      }
    )
    let currentUser = CurrentUser(database: self.database, api: api)
    let user = try await currentUser.user()
    let localUser = try await currentUser.localUser()

    expectNoDifference(localUser, User.mock1)
    expectNoDifference(user, localUser)
  }

  @Test("Removes Current Local User From Cache When Account Deletion Successful")
  func removesCurrentUserFromCacheWhenAccountDeletionSuccessful() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: .mock { request, _ in
        switch request {
        case .currentUser:
          (200, .json(User.mock1))
        case .deleteCurrentUser:
          (204, .data(Data()))
        default:
          (400, .data(Data()))
        }
      }
    )

    let currentUser = CurrentUser(database: database, api: api)
    _ = try await currentUser.user()
    try await currentUser.delete()
    let localUser = try await currentUser.localUser()

    expectNoDifference(localUser, nil)
  }

  @Test("Removes Current Local User From Cache When Sign Out Successful")
  func setsCurrentUserToNilWhenSignOutSuccessful() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: .mock { request, _ in
        switch request {
        case .currentUser:
          (200, .json(User.mock1))
        case .signOut:
          (204, .data(Data()))
        default:
          (400, .data(Data()))
        }
      }
    )

    let currentUser = CurrentUser(database: database, api: api)
    _ = try await currentUser.user()
    try await currentUser.signOut()
    let localUser = try await currentUser.localUser()

    expectNoDifference(localUser, nil)
  }

  @Test("Editing Current User Updates Cached User")
  func editUser() async throws {
    let api = CanIClimbAPI.testInstance(
      transport: .mock { request, _ in
        switch request {
        case .currentUser:
          (200, .json(User.mock1))
        case .editCurrentUser:
          (200, .json(User.mock2))
        default:
          (400, .data(Data()))
        }
      }
    )

    let currentUser = CurrentUser(database: database, api: api)
    _ = try await currentUser.user()
    let editedUser = try await currentUser.edit(
      with: User.Edit(name: User.mock2.name, subtitle: User.mock2.subtitle)
    )
    let localUser = try await currentUser.localUser()

    expectNoDifference(localUser, .mock2)
    expectNoDifference(editedUser, localUser)
  }
}
