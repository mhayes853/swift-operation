import Foundation
import Operation

// MARK: - CachedQuery

extension Post {
  @QueryRequest
  static func cachedQuery(
    id: Int,
    continuation: OperationContinuation<Post?, any Error>
  ) async throws -> Post? {
    async let post = Self.fetchPost(for: id)
    if let cached = try PostCache.shared.post(for: id) {
      continuation.yield(cached)
    }
    return try await post
  }

  private static func fetchPost(for id: Int) async throws -> Post? {
    let url = URL(string: "https://dummyjson.com/posts/\(id)")!
    let (data, resp) = try await URLSession.shared.data(from: url)
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
    try JSONEncoder().encode(post).write(to: self.url(for: id))
  }

  private func url(for postId: Int) -> URL {
    .applicationDirectory.appending(path: "posts-cache/post-\(postId).json")
  }
}
