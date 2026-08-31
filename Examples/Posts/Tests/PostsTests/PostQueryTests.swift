import CustomDump
import Dependencies
import Foundation
import SharingOperation
import Testing

import Posts

@Suite
struct `Post query tests` {
  @Test
  func `Fetches A Post`() async throws {
    let expectedPost = Post(
      id: 42,
      userId: 7,
      title: "Swift Operation",
      body: "Operations make asynchronous work observable."
    )
    let transport = MockHTTPDataTransport { request in
      expectNoDifference(request.url, URL(string: "https://dummyjson.com/posts/42"))
      return response(for: request, data: try JSONEncoder().encode(expectedPost))
    }

    try await withDependencies {
      $0[HTTPDataTransportKey.self] = transport
      $0.defaultOperationClient = OperationClient()
    } operation: {
      @SharedOperation(Post.$query(for: 42).disableAutomaticRunning()) var post
      try await $post.load()

      expectNoDifference(post, expectedPost)
    }
  }

  @Test
  func `Returns Nil For A Missing Post`() async throws {
    let transport = MockHTTPDataTransport { request in
      expectNoDifference(request.url, URL(string: "https://dummyjson.com/posts/404"))
      return response(for: request, statusCode: 404, data: Data())
    }

    try await withDependencies {
      $0[HTTPDataTransportKey.self] = transport
      $0.defaultOperationClient = OperationClient()
    } operation: {
      @SharedOperation(Post.$query(for: 404).disableAutomaticRunning()) var post
      try await $post.load()

      expectNoDifference(post, .some(nil))
    }
  }

  @Test
  func `Propagates A Transport Error`() async {
    struct FetchError: Error, Hashable, Sendable {}

    let transport = MockHTTPDataTransport { _ in throw FetchError() }
    await #expect(throws: FetchError.self) {
      try await withDependencies {
        $0[HTTPDataTransportKey.self] = transport
        $0.defaultOperationClient = OperationClient()
      } operation: {
        @SharedOperation(Post.$query(for: 500).disableAutomaticRunning()) var post
        try await $post.load()
      }
    }
  }
}
