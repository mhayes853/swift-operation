# ``SharingOperation``

A [Sharing](https://github.com/pointfreeco/swift-sharing) adapter for Swift Operation.

## Overview

You can easily observe and interact with your operations using the ``SharedOperation`` property wrapper.

```swift
import SharingOperation
import SwiftUI

struct PostView: View {
  @SharedOperation<Post.Query.State> var post: Post??

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
```
