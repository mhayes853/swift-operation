#if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
  //===----------------------------------------------------------------------===//
  //
  // This source file is part of the Swift Async Algorithms open source project
  //
  // Copyright (c) 2022 Apple Inc. and the Swift project authors
  // Licensed under Apache License v2.0 with Runtime Library Exception
  //
  // See https://swift.org/LICENSE.txt for license information
  //
  //===----------------------------------------------------------------------===//

  /// An `AsyncSequence` that produces elements at regular intervals.
  ///
  /// Internal use only. Not meant to be used outside the library.
  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  package struct _AsyncTimerSequence<C: Clock>: AsyncSequence {
    package typealias Element = C.Instant

    package struct Iterator: AsyncIteratorProtocol {
      var clock: C?
      let interval: C.Instant.Duration
      let tolerance: C.Instant.Duration?
      var last: C.Instant?

      init(interval: C.Instant.Duration, tolerance: C.Instant.Duration?, clock: C) {
        self.clock = clock
        self.interval = interval
        self.tolerance = tolerance
      }

      func nextDeadline(_ clock: C) -> C.Instant {
        let now = clock.now
        let last = self.last ?? now
        let next = last.advanced(by: self.interval)
        if next < now {
          return last.advanced(
            by: self.interval * Int(((next.duration(to: now)) / self.interval).rounded(.up))
          )
        } else {
          return next
        }
      }

      package mutating func next() async -> C.Instant? {
        guard let clock = self.clock else {
          return nil
        }
        let next = self.nextDeadline(clock)
        do {
          try await clock.sleep(until: next, tolerance: self.tolerance)
        } catch {
          self.clock = nil
          return nil
        }
        let now = clock.now
        self.last = next
        return now
      }
    }

    let clock: C
    let interval: C.Instant.Duration
    let tolerance: C.Instant.Duration?

    /// Create an `AsyncTimerSequence` with a given repeating interval.
    package init(interval: C.Instant.Duration, tolerance: C.Instant.Duration? = nil, clock: C) {
      self.clock = clock
      self.interval = interval
      self.tolerance = tolerance
    }

    package func makeAsyncIterator() -> Iterator {
      Iterator(interval: self.interval, tolerance: self.tolerance, clock: self.clock)
    }
  }

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  extension _AsyncTimerSequence: Sendable {}

  @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
  extension _AsyncTimerSequence.Iterator: Sendable {}
#endif
