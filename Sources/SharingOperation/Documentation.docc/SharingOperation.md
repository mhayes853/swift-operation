# ``SharingOperation``

A [Sharing](https://github.com/pointfreeco/swift-sharing) adapter for Swift Operation.

## Overview

You can easily observe and interact with your operations using the ``SharedOperation`` property wrapper.

```swift
import SharingOperation
import SwiftUI

struct PostView: View {
  // This will begin fetching the post.
  @SharedOperation(Post.query(for: 1)) var post

  var body: some View {
    switch self.$post.status {
    case .result(.success(let post)):
      VStack(alignment: .leading) {
        Text(post.title)
        Text(post.body)
      }
    case .result(.failure(let error)):
      Text("Error: \(error.localizedDescription).")
    default:
      ProgressView()
    }
  }
}
```
