#if canImport(SwiftUI)
  import SwiftUI
#endif

// MARK: - QueryStateScheduler

protocol QueryStateScheduler: Sendable {
  func schedule(work: @escaping @Sendable () -> Void)
}

// MARK: - SynchronousStateScheduler

struct SynchronousStateScheduler: QueryStateScheduler {
  @inlinable
  func schedule(work: () -> Void) {
    work()
  }
}

// MARK: - AnimationStateScheduler

#if canImport(SwiftUI)
  struct AnimationStateScheduler: QueryStateScheduler {
    let animation: Animation

    func schedule(work: @escaping @Sendable () -> Void) {
      Task { @MainActor in
        withAnimation(self.animation) { work() }
      }
    }
  }
#endif
