import Foundation

// MARK: - QueryDelayer

public protocol QueryDelayer: Sendable {
  func delay(for seconds: TimeInterval) async throws
}

#if canImport(Dispatch)
  // MARK: - Dispatch Delayer

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
    public static func dispatch(queue: DispatchQueue) -> Self {
      Self(queue: queue)
    }
  }
#endif

// MARK: - Clock Delayer

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
  public static func clock<C: Clock>(_ clock: C) -> Self where Self == ClockDelayer<C> {
    Self(clock: clock)
  }
}

// MARK: - NoDelayer

public struct NoDelayer: QueryDelayer {
  @inlinable
  public func delay(for seconds: TimeInterval) async throws {
  }
}

extension QueryDelayer where Self == NoDelayer {
  public static var noDelay: Self { NoDelayer() }
}

// MARK: - QueryContext

extension QueryContext {
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
