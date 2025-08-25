# ``SharingQuery``

A [Sharing](https://github.com/pointfreeco/swift-sharing) adapter for Swift Operation.

## Overview

You can easily observe and interact with your queries using the ``SharedOperation`` property wrapper.

```swift
import SharingOperation

// This will begin fetching the post.
@SharedOperation(Post.query(for: 1)) var post

if $post.isLoading {
  print("Loading")
} else if let error = $post.error {
  print("Error", error)
} else {
  print("Post", post)
}
```
