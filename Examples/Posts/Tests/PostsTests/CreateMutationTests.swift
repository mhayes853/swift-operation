import CustomDump
import Dependencies
import Foundation
import SharingOperation
import Testing

@testable import Posts

@Suite
struct `Create mutation tests` {
  @Test
  func `Creates A Post`() async throws {
    let arguments = Post.CreateArguments(userId: 7, title: "New Post", body: "Hello!")
    let expectedPost = Post(id: 101, userId: 7, title: "New Post", body: "Hello!")
    let transport = MockHTTPDataTransport { request in
      expectNoDifference(request.url, URL(string: "https://dummyjson.com/posts/add"))
      expectNoDifference(request.httpMethod, "POST")
      expectNoDifference(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
      expectNoDifference(
        try request.httpBody.map {
          try JSONDecoder().decode(Post.CreateArguments.self, from: $0)
        },
        arguments
      )
      return response(for: request, data: try JSONEncoder().encode(expectedPost))
    }

    try await withDependencies {
      $0[HTTPDataTransportKey.self] = transport
      $0.defaultOperationClient = OperationClient()
    } operation: {
      @SharedOperation(Post.$createMutation) var createdPost
      let post = try await $createdPost.mutate(with: arguments)

      expectNoDifference(post, expectedPost)
      expectNoDifference(createdPost, expectedPost)
    }
  }
}
