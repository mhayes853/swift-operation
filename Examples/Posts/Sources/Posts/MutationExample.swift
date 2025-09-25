import Foundation
import SharingOperation
import SwiftUI

// MARK: - CreateMutation

extension Post {
  static let createMutation = CreateMutation()

  struct CreateMutation: MutationRequest, Hashable, Sendable {
    struct Arguments: Codable, Sendable {
      let userId: Int
      let title: String
      let body: String
    }

    func mutate(
      isolation: isolated (any Actor)?,
      with arguments: Arguments,
      in context: OperationContext,
      with continuation: OperationContinuation<Post, any Error>
    ) async throws -> Post {
      let url = URL(string: "https://dummyjson.com/posts/add")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.httpBody = try JSONEncoder().encode(arguments)
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      let (data, _) = try await URLSession.shared.data(for: request)
      return try JSONDecoder().decode(Post.self, from: data)
    }
  }
}

// MARK: - CreatePostView

struct CreatePostView: View {
  @Environment(\.dismiss) private var dismiss
  let userId: Int
  @State private var title = ""
  @State private var postBody = ""
  @SharedOperation(Post.createMutation) private var create

  var body: some View {
    Form {
      TextField("Title", text: self.$title)
      TextField("Body", text: self.$postBody)

      Button(self.$create.isLoading ? "Creating..." : "Create") {
        Task {
          let args = Post.CreateMutation.Arguments(
            userId: self.userId,
            title: self.title,
            body: self.postBody
          )
          try await self.$create.mutate(with: args)
          self.dismiss()
        }
      }
      .disabled(self.$create.isLoading)

      if let error = self.$create.error {
        Text("Error: \(error.localizedDescription)")
      }
    }
    .navigationTitle("Create Post")
  }
}

#Preview {
  CreatePostView(userId: 1)
}
