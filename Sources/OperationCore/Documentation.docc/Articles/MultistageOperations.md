# Multistage Operations

Learn how to utilize ``OperationContinuation`` to yield multiple data updates from your operation while its running.

## Overview

In many cases, it can be useful to yield multiple data updates from your operation while its running. For instance, you may want to populate your UI with locally stored or cached data while you fetch fresh data from a server. Or, you maybe your operation represents a multistep or long-running business workflow, and you want to yield data for each step to your UI to update the user on its progress. Another possibility could be streaming LLM responses from FoundationModels or from a server-side LLM.

All of this is possible by utilizing the `OperationContinuation` that's passed to your operation. Let's explore how we can use it!

## Yielding Cached Data While Fetching Fresh Data

Let's start with a simple workflow. Fetching data from your server may be expensive, so you may want to yield in-memory or placeholder data while you fetch fresh data from your server.

```swift
final class Cache: Sendable {
  static let shared = Cache()

  subscript(key: String) -> QueryData? {
    get {
      // ...
    }
    set {
      // ...
    }
  }
}

struct QueryData: Codable, Sendable {
  // ...
}

extension QueryData {
  @QueryRequest
  static func cacheableQuery(
    for key: String,
    continuation: OperationContinuation<QueryData, any Error>
  ) asycn throws -> QueryData {
    if let cachedData = Cache.shared[key] {
      continuation.yield(cachedData)
    }
    let freshData = try await fetchFreshData()
    Cache.shared[key] = freshData
    return freshData
  }
}
```

In the above example, we first yield a cached value from the query if one exists in the cache, and then afterwards we fetch the latest data from the network. After receiving the fresh data, we ensure to update the cache with the fresh data before returning.

Now we can consume the yielded cached data in our UI while we fetch the real data in the background. Furthermore, `isLoading` will still be true on the query state while the fresh data is being fetched despite yielding cached data. This allows you to still show a loading spinner in your UI at the same time the cached data is displayed.

```swift
import SwiftUI
import SharingOperation

struct ContentView: View {
  @SharedOperation(QueryData.$cacheableQuery(for: "example")) var value

  var body: some View {
    VStack {
      // This will still be visible while the cached data is displayed.
      if $value.isLoading {
        ProgressView()
      }
      if let value {
        QueryDataView(data: value)
      }
    }
  }
}
```

## Yielding Errors

In addition to yielding values, you can also yield intermittent errors from your operation while still fetching data. For instance, you may persist data locally on disk to support offline mode in your app. Thus, loading the persisted data has a possibility of failing, and we can yield an error in the meantime whilst we fetch the fresh data from the network.

```swift
@QueryRequest
func diskCacheableQuery(
  key: String,
  continuation: OperationContinuation<QueryData, any Error>
) async throws -> QueryData {
  let path = URL.documentsDirectory.appending(path: "cache/\(key)")
  do {
    let rawData = try Data(contentsOf: path)
    let queryData = try JSONDecoder().decode(
      QueryData.self,
      from: rawData
    )
    continuation.yield(queryData)
  } catch {
    continuation.yield(error: error)
  }
  let freshData = try await fetchFreshData()
  try JSONEncoder().encode(freshData).write(to: path)
  return freshData
}
```

If we can't load data from the disk, we'll yield an error from the query. However, the query itself has not failed as we can still fetch fresh data from the network and attempt to save it to disk. In the meantime, you can still decide to display in intermittent error in your UI.

## Yielding Data Over Time

Another use case for `OperationContinuation` would be to yield data from a remote source as it comes in chunks.

```swift
@QueryRequest
func linesQuery(
  url: URL,
  continuation: OperationContinuation<[String], any Error>
) async throws -> [String] {
  // Apply a time freeze to the context so that
  // valueLastUpdatedAt remains consistent when
  // many chunks of data are yielded.
  var context = context
  context.operationClock = context.operationClock.frozen()
  var lines = [String]()
  for try await line in url.lines {
    lines.append(line)
    continuation.yield(lines, context)
  }
  return lines
}
```

In the above example, we stream each line of text from a URL using an `AsyncSequence` and yield the result using the continuation.

## Yielding Similar Data Whilst Fetching Actual Data

At times, you may be able to yield similar data to the actual data your fetching whilst fetching the actual data. For instance, you may be fetching a list of events within a geospatial region described as the following data type.

```swift
struct Region: Hashable, Sendable {
  let latitude: Double
  let longitude: Double
  let radius: Double

  func distance(to other: Self) -> Double {
    // Use the Haversine formula to calculate this...
  }
}
```

However, you may have previously fetched a list of events from a nearby region, and you could yield that list while you fetch the events for the actual region.

```swift
struct EventsList: Sendable {
  let region: Region
  let events: [Event]
}

extension EventsList {
  @QueryRequest(
    path: .custom { (region: Region) in ["nearby-events", region] }
  )
  static func nearbyQuery(
    for region: Region,
    context: OperationContext,
    continuation: OperationContinuation<EventsList, any Error>
  ) async throws -> EventsList {
    guard let client = context.operationClient else {
      return try await fetchActualEventList(region)
    }
    // Look for other EventLists we've fetched and use the data from
    // any that are within the distance threshold.
    let stores = client.stores(
      matching: ["nearby-events"],
      of: State.self
    )
    for store in stores {
      let distance = store.currentValue.region.distance(to: region)
      if distance < context.distanceThreshold {
        continuation.yield(
          EventsList(region: region, events: list.events)
        )
      }
    }
    return try await fetchActualEventList(region)
  }
}

extension OperationContext {
  var distanceThreshold: Double {
    get { self[DistanceThresholdKey.self] }
    set { self[DistanceThresholdKey.self] = newValue }
  }

  private enum DistanceThresholdKey: Key {
    static let defaultValue = 1000.0
  }
}
```

In `NearbyEventsQuery` we utilize the pattern matching ability of ``OperationClient`` and ``OperationPath`` to find previous event lists that we've fetched around the query's region. If the event lists's `region` is within some distance threshold to the query's distance, then we can yield the events from that list whilst we fetch the actual events list for the query's region.

## Conclusion

In this article, you learned how to use `OperationContinuation` to yield multiple data updates from your operations. With `OperationContinuation` its possible to implement a variety of operations that allow your UI to be responsive whilst long or even flakey data fetching workflows occur in the background. When you yield either data or an error from your operation, your UI can still remain in a loading state as the `isLoading` property is still true whilst your operation hasn't fully finished running.
