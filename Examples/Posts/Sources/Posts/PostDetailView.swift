import SwiftUI

struct PostDetailView: View {
  let post: Post

  var body: some View {
    VStack(alignment: .leading) {
      Text(post.title).font(.headline)
      Text(post.body)
    }
  }
}
