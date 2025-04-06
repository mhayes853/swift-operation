import CustomDump
import Query
import Testing

@Suite("StateManagement tests")
struct StateManagementTests {
  private let client = QueryClient()

  @Test("Updates UserFriendsList From Mutation")
  func updatesUserFriendsListFromMutation() async throws {
    let store = self.client.store(for: UserFriendsQuery(userId: 1))
    try await store.fetchNextPage()

    expectNoDifference(
      store.currentValue,
      [InfiniteQueryPage(id: 0, value: [User(id: 10, relationship: .notFriends)])]
    )

    let store2 = self.client.store(for: SendFriendRequestMutation())
    try await store2.mutate(with: SendFriendRequestMutation.Arguments(userId: 10))

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

private struct UserFriendsQuery: InfiniteQueryRequest {
  typealias PageID = Int
  typealias PageValue = [User]

  let userId: Int
  let initialPageId = 0

  var path: QueryPath {
    ["user-friends", self.userId]
  }

  func pageId(
    after page: InfiniteQueryPage<Int, [User]>,
    using paging: InfiniteQueryPaging<Int, [User]>,
    in context: QueryContext
  ) -> Int? {
    page.id + 1
  }

  func fetchPage(
    using paging: InfiniteQueryPaging<Int, [User]>,
    in context: QueryContext,
    with continuation: QueryContinuation<[User]>
  ) async throws -> [User] {
    [User(id: 10, relationship: .notFriends)]
  }
}

private struct SendFriendRequestMutation: MutationRequest, Hashable {
  typealias Value = Void

  struct Arguments: Sendable {
    let userId: Int
  }

  func mutate(
    with arguments: Arguments,
    in context: QueryContext,
    with continuation: QueryContinuation<Void>
  ) async throws {
    guard let client = context.queryClient else { return }
    for (_, store) in client.stores(matching: ["user-friends"]) {
      guard let store = store.base as? QueryStore<UserFriendsQuery.State> else { continue }
      let pages = store.currentValue.map { page in
        InfiniteQueryPage(
          id: page.id,
          value: page.value.map { user in
            var user = user
            if user.id == arguments.userId {
              user.relationship = .friendRequestSent
            }
            return user
          }
        )
      }
      store.currentValue = InfiniteQueryPages(uniqueElements: pages)
    }
  }
}
