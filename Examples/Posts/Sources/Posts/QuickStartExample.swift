import Foundation
import SharingOperation
import SwiftUI

// MARK: - Query

extension Post {
  static func query(for id: Int) -> some QueryRequest<Post?, any Error> {
    // The modifiers on the query are applied by default, they are
    // only being shown to demonstrate how to configure operations.
    Self.$query(for: id)
      .retry(limit: 3)
      .deduplicated()
      .rerunOnChange(of: .connected(to: NWPathMonitorObserver.startingShared()))
  }

  @QueryRequest
  private static func query(for id: Int) async throws -> Post? {
    let url = URL(string: "https://dummyjson.com/posts/\(id)")!
    let (data, resp) = try await URLSession.shared.data(from: url)
    if (resp as? HTTPURLResponse)?.statusCode == 404 {
      return nil
    }
    return try JSONDecoder().decode(Post.self, from: data)
  }
}

// MARK: - PostView

struct PostView: View {
  @SharedOperation<QueryState<Post?, any Error>> var post: Post??

  init(id: Int) {
    // By default, this will begin fetching the post.
    self._post = SharedOperation(Post.query(for: id))
  }

  var body: some View {
    Group {
      VStack {
        switch self.$post.status {
        case .result(.success(let post)):
          if let post {
            PostDetailView(post: post)
          } else {
            Text("Post Not Found")
          }
        case .result(.failure(let error)):
          Text("Error: \(error.localizedDescription).")
        case .loading:
          ProgressView()
        default:
          EmptyView()
        }
        Button("Reload") {
          Task { try await self.$post.fetch() }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

#Preview {
  PostView(id: 1)
}
