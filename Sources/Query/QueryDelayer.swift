import Foundation

// MARK: - QueryDelayer

/// A protocol for artificially delaying queries.
///
/// Artificial delays are useful for adding backoff to query retries, avoiding rate limits, and
/// much more. You can override the ``QueryContext/queryDelayer`` context property to override the
/// delay mechanism for your queries.
public protocol QueryDelayer: Sendable {
  /// Delay for the specified number of seconds.
  ///
  /// - Parameter seconds: The number of seconds to delay for.
  func delay(for seconds: TimeInterval) async throws
}

#if canImport(Dispatch)
  // MARK: - Dispatch Delayer

  /// A ``QueryDelayer`` that uses a `DispatchQueue` and `DispatchWorkItem`.
  public struct DispatchDelayer {
    let queue: DispatchQueue
  }

  extension DispatchDelayer: QueryDelayer {
    public func delay(for seconds: TimeInterval) async throws {
      nonisolated(unsafe) var state:
        (workItem: DispatchWorkItem?, continuation: UnsafeContinuation<Void, Error>?) = (nil, nil)
      try await withTaskCancellationHandler {
        try await withUnsafeThrowingContinuation { continuation in
          state.workItem = DispatchWorkItem {
            guard !Task.isCancelled else { return }
            continuation.resume()
          }
          state.continuation = continuation
          self.queue.asyncAfter(deadline: .now() + seconds, execute: state.workItem!)
        }
      } onCancel: {
        state.workItem?.cancel()
        state.continuation?.resume(throwing: CancellationError())
      }
    }
  }

  extension QueryDelayer where Self == DispatchDelayer {
    /// A ``QueryDelayer`` that uses a `DispatchQueue` and `DispatchWorkItem`.
    ///
    /// - Parameter queue: The queue to delay on.
    /// - Returns: A ``DispatchDelayer``.
    public static func dispatch(queue: DispatchQueue) -> Self {
      Self(queue: queue)
    }
  }
#endif

// MARK: - Clock Delayer

/// A ``QueryDelayer`` that uses the `Clock` protocol to delay queries.
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct ClockDelayer<C: Clock> where C.Duration == Duration {
  let clock: C
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension ClockDelayer: QueryDelayer {
  public func delay(for seconds: TimeInterval) async throws {
    try await clock.sleep(for: .seconds(seconds))
  }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension QueryDelayer {
  /// A ``QueryDelayer`` that uses the `Clock` protocol to delay queries.
  ///
  /// - Parameter clock: The `Clock` to use to perform delays.
  /// - Returns: A ``ClockDelayer``.
  public static func clock<C: Clock>(_ clock: C) -> Self where Self == ClockDelayer<C> {
    Self(clock: clock)
  }
}

// MARK: - NoDelayer

/// A ``QueryDelayer`` that performs no delays.
///
/// This is especially useful for testing, where having delays can slow down your test suite.
public struct NoDelayer: QueryDelayer {
  @inlinable
  public func delay(for seconds: TimeInterval) async throws {
  }
}

extension QueryDelayer where Self == NoDelayer {
  /// A ``QueryDelayer`` that performs no delays.
  ///
  /// This is especially useful for testing, where having delays can slow down your test suite.
  public static var noDelay: Self { NoDelayer() }
}

// MARK: - QueryContext

extension QueryContext {
  /// The current ``QueryDelayer`` in this context.
  ///
  /// The default value is platform dependent. On Darwin platforms,
  /// ``QueryDelayer/dispatch(queue:)`` is the default value, and ``QueryDelayer/clock(_:)`` is the
  /// default value on all other platforms.
  public var queryDelayer: any QueryDelayer {
    get { self[QueryDelayerKey.self] }
    set { self[QueryDelayerKey.self] = newValue }
  }

  private enum QueryDelayerKey: Key {
    static var defaultValue: any QueryDelayer {
      #if canImport(Darwin)
        .dispatch(queue: .global())
      #else
        .clock(ContinuousClock())
      #endif
    }
  }
}
