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

// MARK: - ListPage

extension Post {
  struct ListPage: Hashable, Sendable {
    var posts: IdentifiedArrayOf<Post>
    let total: Int
  }
}

extension Post.ListPage {
  struct ID: Hashable, Sendable {
    let limit: Int
    let skip: Int
  }
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

extension Post {
  protocol ListByTagLoader: Sendable {
    func posts(with tag: String, for page: ListPage.ID) async throws -> ListPage
  }
}

enum PostListByTagLoaderKey: DependencyKey {
  static let liveValue: any Post.ListByTagLoader = DummyJSONAPI.shared
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

extension Post {
  static func listByTagQuery(
    tag: String
  ) -> some InfiniteQueryRequest<ListPage.ID, ListPage> {
    ListByTagQuery(tag: tag)
  }
  
  struct ListByTagQuery: InfiniteQueryRequest {
    typealias PageID = Post.ListPage.ID
    typealias PageValue = Post.ListPage
    
    let tag: String
    
    let initialPageId = Post.ListPage.ID(limit: 10, skip: 0)
    
    var path: QueryPath {
      ["posts", self.tag]
    }
    
    func pageId(
      after page: InfiniteQueryPage<PageID, PageValue>,
      using paging: InfiniteQueryPaging<PageID, PageValue>,
      in context: QueryContext
    ) -> PageID? {
      let nextId = PageID(limit: page.id.limit, skip: page.id.skip + page.id.limit)
      return nextId.skip >= page.value.total ? nil : nextId
    }
    
    func fetchPage(
      using paging: InfiniteQueryPaging<PageID, PageValue>,
      in context: QueryContext,
      with continuation: QueryContinuation<PageValue>
    ) async throws -> PageValue {
      @Dependency(PostListByTagLoaderKey.self) var loader
      return try await loader.posts(with: self.tag, for: paging.pageId)
    }
  }
}
