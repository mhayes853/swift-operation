#if canImport(SwiftUI)
  import SwiftUI
#endif

#if SwiftNavigation
  import SwiftNavigation
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

// MARK: - UITransactionStateScheduler

#if SwiftNavigation
  struct UITransactionStateScheduler: QueryStateScheduler {
    let transaction: UITransaction

    func schedule(work: @escaping @Sendable () -> Void) {
      Task { @MainActor in
        withUITransaction(self.transaction) { work() }
      }
    }
  }
#endif
