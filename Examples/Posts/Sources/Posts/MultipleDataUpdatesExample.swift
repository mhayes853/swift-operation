import Dependencies
import Foundation
import Operation

// MARK: - CachedQuery

extension Post {
  @QueryRequest
  static func cachedQuery(
    id: Int,
    continuation: OperationContinuation<Post?, any Error>
  ) async throws -> Post? {
    async let fetchedPost = Self.fetchPost(for: id)
    if let cached = try? PostCache.shared.post(for: id) {
      continuation.yield(cached)
    }
    let post = try await fetchedPost
    if let post {
      try? PostCache.shared.save(post: post, for: id)
    }
    return post
  }

  private static func fetchPost(for id: Int) async throws -> Post? {
    @Dependency(HTTPDataTransportKey.self) var transport
    let url = URL(string: "https://dummyjson.com/posts/\(id)")!
    let (data, resp) = try await transport.data(for: URLRequest(url: url))
    if (resp as? HTTPURLResponse)?.statusCode == 404 {
      return nil
    }
    return try JSONDecoder().decode(Post.self, from: data)
  }
}

// MARK: - PostCache

final class PostCache: Sendable {
  static let shared = PostCache()

  func post(for id: Int) throws -> Post? {
    guard let data = try? Data(contentsOf: self.url(for: id)) else { return nil }
    return try JSONDecoder().decode(Post.self, from: data)
  }

  func save(post: Post, for id: Int) throws {
    let url = self.url(for: id)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try JSONEncoder().encode(post).write(to: url, options: .atomic)
  }

  private func url(for postId: Int) -> URL {
    URL.cachesDirectory.appending(path: "posts-cache/post-\(postId).json")
  }
}
