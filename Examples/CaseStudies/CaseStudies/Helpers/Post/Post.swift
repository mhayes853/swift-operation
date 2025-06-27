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

// MARK: - Protocols

extension Post {
  protocol Searcher: Sendable {
    func search(by text: String) async throws -> IdentifiedArrayOf<Post>
  }
}

enum PostSearcherKey: DependencyKey {
  static let liveValue: any Post.Searcher = DummyJSONAPI.shared
}

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

extension Post {
  static func searchQuery(
    by text: String
  ) -> some QueryRequest<IdentifiedArrayOf<Self>, SearchQuery.State> {
    SearchQuery(text: text)
  }
  
  struct SearchQuery: QueryRequest, Hashable {
    let text: String
    
    func fetch(
      in context: QueryContext,
      with continuation: QueryContinuation<IdentifiedArrayOf<Post>>
    ) async throws -> IdentifiedArrayOf<Post> {
      @Dependency(PostSearcherKey.self) var posts
      return try await posts.search(by: self.text)
    }
  }
}
