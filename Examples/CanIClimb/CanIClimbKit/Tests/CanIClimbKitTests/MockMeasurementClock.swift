import Synchronization

// MARK: - MockMeasurementClock

final class MockMeasurementClock {
  private struct State {
    var offset = Duration.zero
  }

  private let state = Mutex(State())

  let stride: Duration

  init(stride: Duration) {
    self.stride = stride
  }
}

// MARK: - Clock Conformance

extension MockMeasurementClock: Clock {
  typealias Duration = Swift.Duration

  struct Instant: InstantProtocol {
    private let offset: Duration

    init(offset: Duration = .zero) {
      self.offset = offset
    }

    func advanced(by duration: Duration) -> Self {
      Self(offset: self.offset + duration)
    }

    func duration(to other: Self) -> Duration {
      other.offset - self.offset
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.offset < rhs.offset
    }
  }

  var now: Instant {
    self.state.withLock { state in
      defer { state.offset += self.stride }
      return Instant(offset: state.offset)
    }
  }

  var minimumResolution: Duration {
    Duration.zero
  }

  func sleep(until deadline: Instant, tolerance: Instant.Duration?) async throws {
    try Task.checkCancellation()
  }
}
