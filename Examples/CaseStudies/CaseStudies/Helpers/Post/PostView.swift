import SwiftUI

struct PostView: View {
  let post: Post

  var body: some View {
    VStack(alignment: .leading) {
      Text(self.post.title).font(.headline)
      Text(self.post.content)
    }
  }
}

struct PostLikeButton: View {
  let post: Post
  let action: () -> Void

  var body: some View {
    Button(action: self.action) {
      HStack(alignment: .center) {
        Image(systemName: self.post.isUserLiking ? "heart.fill" : "heart")
          .foregroundStyle(self.post.isUserLiking ? Color.pink : Color.primary)
        Text("\(self.post.likeCount)")
      }
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(self.post.isUserLiking ? "Unlike post" : "Like post")
    .accessibilityValue("\(self.post.likeCount) likes")
  }
}
