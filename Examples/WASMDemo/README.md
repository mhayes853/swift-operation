# WASMDemo

A simple demo of how to use Swift Operation and WASM to build a browser application.

Inspired by [PointFree's](https://www.pointfree.co/) obsession with counters, the app is a simple counter app that displays a cool fact of the current number, and the nth prime number of the current number.

![An image displaying the counter app with the network status indicating that the user is connected to the internet, a total sum counter of 1100, and 3 other counters at 1000, 100, and 0, each displaying a number fact and the nth prime number of the current count.](./assets/app.png)

You can see how Swift Operation will easily remember the state of previous queries as you increment and decrement each counter. If you switch to another browser tab, then back to the app, the app will automatically refresh the latest data from the number fact API.

The app makes use of the `SharingOperation` integration such that it can use the `@SharedOperation` property wrapper, and uses [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) for dependency injection within queries. Number facts are fetched from [Wikipedia's REST API](https://en.wikipedia.org/api/rest_v1/).

Calculating the nth prime number is a blocking computation that takes a while for large numbers, so this project also shows off how one can use `WebWorkerTaskExecutor` from JavaScriptKit to avoid blocking the browser UI thread. The executor is combined with the `taskConfiguration` query modifier, which lets you set the `TaskExecutor` preference of the query. See the [Task Executor Preference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0417-task-executor-preference.md) for more on how task executors work.

[JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) is used to interact with the browser's DOM, render the UI, and perform network requests. Furthermore, the app uses a small `observe` utility (see `Observe.swift`) to listen to changes from `@Observable` models in the UI.

Lastly, the app has a test suite written in XCTest for all of its business logic, which should serve as an example of how to write tests for your queries in the context of your app's architecture.

## Running the App

Install a Swift toolchain (the standalone one, not the one bundled with Xcode) using [swiftly](https://github.com/swiftlang/swiftly), and make sure it is the `swift` on your `PATH` — `swift --version` should report 6.3.2 rather than an Xcode toolchain version.

```sh
brew install swiftly
swiftly init
swiftly install 6.3.2 --use
```

Then install a matching Swift SDK for WebAssembly. It has to be built from the same compiler version as your toolchain, and swift.org only publishes single threaded SDKs, so use the `wasm32-unknown-wasip1-threads` bundle from [swiftwasm](https://github.com/swiftwasm/swift/releases) to get web workers.

```sh
swift sdk install \
  https://github.com/swiftwasm/swift/releases/download/swift-wasm-6.3-SNAPSHOT-2026-08-14-a/swift-wasm-6.3-SNAPSHOT-2026-08-14-a-wasm32-unknown-wasip1-threads.artifactbundle.zip \
  --checksum 8329ea9b7a35a59df46515c518d9f7c669e5f8c5be91f7ec260e2cef6f3352ab
```

Now run `./run-dev.sh`, which builds the app and serves it on <http://localhost:3000>.

The scripts select that SDK by its identifier, `6.3-SNAPSHOT-2026-08-14-a-wasm32-unknown-wasip1-threads`. Set `SWIFT_SDK` to use a different one — `SWIFT_SDK=swift-6.3.2-RELEASE_wasm ./run-dev.sh` builds against swift.org's single threaded SDK, which compiles out the `WebWorkerTaskExecutor` paths and computes the nth prime on the main thread.

### Running the Tests

The test suite runs in a real browser via [Playwright](https://playwright.dev), so install it once:

```sh
npm install && npx playwright install chromium
```

Then run `./test.sh`.
