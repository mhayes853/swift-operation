# ``QuerySwiftUI``

A SwiftUI adapter for Swift Query.

## Overview

You can easily observe a query's state in a SwiftUI view using the `@State.Query` property wrapper.

```swift
import QuerySwiftUI

struct PostView: View {
  @State.Query<Post.Query> var state: Post.Query.State

  init(id: Int) {
    self._state = State.Query(Post.query(for: id))
  }

  var body: some View {
    VStack {
      switch state.status {
      case .idle:
        Text("Idle")
      case .loading:
        ProgressView()
      case let .result(.success(post)):
        Text(post.title)
        Text(post.body)
      case let .result(.failure(error)):
        Text(error.localizedDescription)
      }
    }
  }
}
```
