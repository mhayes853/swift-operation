import SwiftUI

struct PostView: View {
  let post: Post
  let onLikeTapped: (() -> Void)?
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(self.post.title).font(.headline)
      Text(self.post.content)
      
      if let onLikeTapped {
        Button {
          onLikeTapped()
        } label: {
          HStack(alignment: .center) {
            Image(systemName: self.post.isUserLiking ? "heart.fill" : "heart")
              .foregroundStyle(self.post.isUserLiking ? Color.pink : Color.primary)
            Text("\(self.post.likeCount)")
          }
        }
        .padding(.top, 5)
      }
    }
  }
}
