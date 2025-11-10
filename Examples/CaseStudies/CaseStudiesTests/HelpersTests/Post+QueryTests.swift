import CustomDump
import Dependencies
import Foundation
import SharingOperation
import Testing

@testable import CaseStudies

@Suite("Post+Query tests")
struct PostQueryTests {
  @Test("Returns Post From Dummy JSON API")
  func returnsPostFromDummyJSONAPI() async throws {
    let postJSON = """
      {
        "id": 1,
        "title": "His mother had always taught him",
        "body": "His mother had always taught him not to ever think of himself as better than others. He'd tried to live by this motto. He never looked down on those who were less fortunate or who had less money than him. But the stupidity of the group of people he was talking to made him change his mind.",
        "tags": [
          "history",
          "american",
          "crime"
        ],
        "reactions": {
          "likes": 192,
          "dislikes": 25
        },
        "views": 305,
        "userId": 121
      }
      """
    let transport = MockHTTPDataTransport { _ in (200, .data(Data(postJSON.utf8))) }
    try await withDependencies {
      $0[PostsKey.self] = DummyJSONAPI(transport: transport)
    } operation: {
      @SharedOperation(Post.$query(for: 1)) var post
      try await $post.load()

      let expectedPost = Post(
        id: 1,
        title: "His mother had always taught him",
        content: """
          His mother had always taught him not to ever think of himself as better than others. \
          He'd tried to live by this motto. He never looked down on those who were less fortunate \
          or who had less money than him. But the stupidity of the group of people he was talking \
          to made him change his mind.
          """,
        likeCount: 192,
        isUserLiking: false
      )
      expectNoDifference(post, expectedPost)
    }
  }

  @Test("Returns Nil When ID Not Found From Dummy JSON API")
  func returnsNilWhenRandomNotFoundFromDummyJSON() async throws {
    let transport = MockHTTPDataTransport { _ in (404, .data(Data())) }
    try await withDependencies {
      $0[PostsKey.self] = DummyJSONAPI(transport: transport)
    } operation: {
      @SharedOperation(Post.$query(for: 1)) var post
      try await $post.load()

      expectNoDifference(post, .some(nil))
    }
  }

  @Test("Searches For Posts")
  func searchesForPosts() async throws {
    let postJSON = """
      {
        "posts": [
          {
            "id": 1,
            "title": "His mother had always taught him",
            "body": "His mother had always taught him not to ever think of himself as better than others. He'd tried to live by this motto. He never looked down on those who were less fortunate or who had less money than him. But the stupidity of the group of people he was talking to made him change his mind.",
            "tags": [
              "history",
              "american",
              "crime"
            ],
            "reactions": {
              "likes": 192,
              "dislikes": 25
            },
            "views": 305,
            "userId": 121
          }
        ],
        "total": 1,
        "skip": 0,
        "limit": 30
      }
      """
    let transport = MockHTTPDataTransport { _ in (200, .data(Data(postJSON.utf8))) }
    try await withDependencies {
      $0[PostSearcherKey.self] = DummyJSONAPI(transport: transport)
    } operation: {
      @SharedOperation(Post.$searchQuery(by: "blob")) var posts
      try await $posts.load()

      let expectedPost = Post(
        id: 1,
        title: "His mother had always taught him",
        content: """
          His mother had always taught him not to ever think of himself as better than others. \
          He'd tried to live by this motto. He never looked down on those who were less fortunate \
          or who had less money than him. But the stupidity of the group of people he was talking \
          to made him change his mind.
          """,
        likeCount: 192,
        isUserLiking: false
      )
      expectNoDifference(posts, [expectedPost])
    }
  }

  @Test("Loads Page By Tag From Dummy JSON")
  func loadsPageByTagFromDummyJSON() async throws {
    let json = """
      {
        "posts": [
          {
            "id": 42,
            "title": "You know that tingly feeling you get on the back of your neck sometimes?",
            "body": "You know that tingly feeling you get on the back of your neck sometimes? I just got that feeling when talking with her. You know I don't believe in sixth senses, but there is something not right with her. I don't know how I know, but I just do.",
            "tags": [
              "mystery",
              "french",
              "american"
            ],
            "reactions": {
              "likes": 177,
              "dislikes": 11
            },
            "views": 3757,
            "userId": 188
          }
        ],
        "total": 38,
        "skip": 10,
        "limit": 10
      }
      """
    let transport = MockHTTPDataTransport { request in
      guard
        request.url?.path() == "/posts/tag/mystery"
          && request.url?.query() == "limit=10&skip=0"
      else {
        return (400, .data(Data()))
      }
      return (200, .data(Data(json.utf8)))
    }

    try await withDependencies {
      $0[PostListByTagLoaderKey.self] = DummyJSONAPI(transport: transport)
    } operation: {
      @SharedOperation(Post.listByTagQuery(tag: "mystery")) var list
      try await $list.load()

      let expectedPost = Post(
        id: 42,
        title: "You know that tingly feeling you get on the back of your neck sometimes?",
        content: """
          You know that tingly feeling you get on the back of your neck sometimes? I just got that \
          feeling when talking with her. You know I don't believe in sixth senses, but there is \
          something not right with her. I don't know how I know, but I just do.
          """,
        likeCount: 177,
        isUserLiking: false
      )
      expectNoDifference(
        list,
        Pages(
          uniqueElements: [
            Page(
              id: Post.ListPage.ID(limit: 10, skip: 0),
              value: Post.ListPage(posts: [expectedPost], total: 38)
            )
          ]
        )
      )
      expectNoDifference($list.nextPageId, Post.ListPage.ID(limit: 10, skip: 10))
    }
  }

  @Test("List by Tag has no Next Page ID when Skip and Limit go Above Total")
  func listByTagHasNoNextPageID() async throws {
    let json = """
      {
        "posts": [
          {
            "id": 42,
            "title": "You know that tingly feeling you get on the back of your neck sometimes?",
            "body": "You know that tingly feeling you get on the back of your neck sometimes? I just got that feeling when talking with her. You know I don't believe in sixth senses, but there is something not right with her. I don't know how I know, but I just do.",
            "tags": [
              "mystery",
              "french",
              "american"
            ],
            "reactions": {
              "likes": 177,
              "dislikes": 11
            },
            "views": 3757,
            "userId": 188
          }
        ],
        "total": 8,
        "skip": 0,
        "limit": 10
      }
      """
    let transport = MockHTTPDataTransport { _ in (200, .data(Data(json.utf8))) }
    try await withDependencies {
      $0[PostListByTagLoaderKey.self] = DummyJSONAPI(transport: transport)
    } operation: {
      @SharedOperation(Post.listByTagQuery(tag: "mystery")) var list
      try await $list.load()

      expectNoDifference($list.nextPageId, nil)
    }
  }
}
