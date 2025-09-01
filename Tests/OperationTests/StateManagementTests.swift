import CustomDump
import Operation
import Testing

@Suite("StateManagement tests")
struct StateManagementTests {
  private let client = OperationClient()

  @Test("Updates UserFriendsList From Mutation")
  func updatesUserFriendsListFromMutation() async throws {
    let store = self.client.store(for: User.friendsQuery(for: 10))
    try await store.fetchNextPage()

    expectNoDifference(
      store.currentValue,
      [InfiniteQueryPage(id: 0, value: [User(id: 10, relationship: .notFriends)])]
    )

    let store2 = self.client.store(for: User.sendFriendRequestMutation)
    try await store2.mutate(with: User.SendFriendRequestMutation.Arguments(userId: 10))

    expectNoDifference(
      store.currentValue,
      [InfiniteQueryPage(id: 0, value: [User(id: 10, relationship: .friendRequestSent)])]
    )
  }
}

private struct User: Hashable, Sendable {
  enum Relationship: Hashable, Sendable {
    case notFriends
    case friendRequestSent
    case friendRequestReceived
    case friends
    case currentUser
  }

  let id: Int
  var relationship: Relationship
}

extension User {
  static func friendsQuery(for id: Int) -> some InfiniteQueryRequest<Int, [User], any Error> {
    FriendsQuery(userId: id)
  }

  struct FriendsQuery: InfiniteQueryRequest {
    typealias PageID = Int
    typealias PageValue = [User]

    let userId: Int
    let initialPageId = 0

    var path: OperationPath {
      ["user-friends", self.userId]
    }

    func pageId(
      after page: InfiniteQueryPage<Int, [User]>,
      using paging: InfiniteQueryPaging<Int, [User]>,
      in context: OperationContext
    ) -> Int? {
      page.id + 1
    }

    func fetchPage(
      isolation: isolated (any Actor)?,
      using paging: InfiniteQueryPaging<Int, [User]>,
      in context: OperationContext,
      with continuation: OperationContinuation<[User], any Error>
    ) async throws -> [User] {
      [User(id: 10, relationship: .notFriends)]
    }
  }
}

extension User {
  static let sendFriendRequestMutation = SendFriendRequestMutation()

  struct SendFriendRequestMutation: MutationRequest, Hashable {
    struct Arguments: Sendable {
      let userId: Int
    }

    func mutate(
      isolation: isolated (any Actor)?,
      with arguments: Arguments,
      in context: OperationContext,
      with continuation: OperationContinuation<Void, any Error>
    ) async throws {
      guard let client = context.operationClient else { return }
      for store in client.stores(matching: ["user-friends"], of: User.FriendsQuery.State.self) {
        let pages = store.currentValue.map { page in
          var page = page
          page.value = page.value.map { user in
            var user = user
            if user.id == arguments.userId {
              user.relationship = .friendRequestSent
            }
            return user
          }
          return page
        }
        store.currentValue = InfiniteQueryPages(uniqueElements: pages)
      }
    }
  }
}
