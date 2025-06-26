import Query
import Dependencies

// MARK: - Post

struct Post: Hashable, Sendable, Identifiable {
  let id: Int
  var title: String
  var content: String
  var likeCount: Int
  var isUserLiking: Bool
}

// MARK: - Posts

protocol Posts: Sendable {
  func post(with id: Int) async throws -> Post?
}

enum PostsKey: DependencyKey {
  static let liveValue: any Posts = DummyJSONAPI.shared
}

// MARK: - Query

extension Post {
  static func query(for id: Int) -> some QueryRequest<Self?, Query.State> {
    Query(id: id)
  }
  
  struct Query: QueryRequest, Hashable {
    let id: Int
    
    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<Post?>
    ) async throws -> Post? {
      @Dependency(PostsKey.self) var posts
      return try await posts.post(with: self.id)
    }
  }
}
