import CustomDump
import Dependencies
import Foundation
import SharingOperation
import Testing

@testable import Posts

@Suite
struct `Feed query tests` {
  @Test
  func `Fetches The Initial Page`() async throws {
    let post = Post(id: 1, userId: 2, title: "First", body: "First post")
    let expectedPage = Post.FeedPage(posts: [post], total: 1, skip: 0)
    let transport = MockHTTPDataTransport { request in
      let components = request.url.flatMap {
        URLComponents(url: $0, resolvingAgainstBaseURL: false)
      }
      expectNoDifference(components?.path, "/posts")
      expectNoDifference(
        components?.queryItems,
        [
          URLQueryItem(name: "limit", value: "10"),
          URLQueryItem(name: "skip", value: "0")
        ]
      )
      return response(for: request, data: try JSONEncoder().encode(expectedPage))
    }

    try await withDependencies {
      $0[HTTPDataTransportKey.self] = transport
      $0.defaultOperationClient = OperationClient()
    } operation: {
      @SharedOperation(Post.feedQuery.disableAutomaticRunning()) var feed
      try await $feed.fetchNextPage()

      expectNoDifference(feed, [Page(id: 0, value: expectedPage)])
      expectNoDifference($feed.hasNextPage, false)
    }
  }
}
