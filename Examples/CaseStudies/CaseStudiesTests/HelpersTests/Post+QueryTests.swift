@testable import CaseStudies
import SharingQuery
import Testing
import Foundation
import CustomDump
import Dependencies

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
      @SharedQuery(Post.query(for: 1)) var post
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
      @SharedQuery(Post.query(for: 1)) var post
      try await $post.load()
      
      expectNoDifference(post, .some(nil))
    }
  }
}
