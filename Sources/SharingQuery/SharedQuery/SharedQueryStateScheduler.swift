#if canImport(SwiftUI)
  import SwiftUI
#endif

#if SwiftNavigation
  import SwiftNavigation
#endif

// MARK: - SharedQueryStateScheduler

public protocol SharedQueryStateScheduler: Sendable {
  func schedule(work: @escaping @Sendable () -> Void)
}

// MARK: - SynchronousStateScheduler

public struct SynchronousStateScheduler: SharedQueryStateScheduler {
  @inlinable
  public func schedule(work: () -> Void) {
    work()
  }
}

extension SharedQueryStateScheduler where Self == SynchronousStateScheduler {
  public static var synchronous: Self { SynchronousStateScheduler() }
}

// MARK: - AnimationStateScheduler

#if canImport(SwiftUI)
  public struct AnimationStateScheduler: SharedQueryStateScheduler {
    let animation: Animation

    public func schedule(work: @escaping @Sendable () -> Void) {
      Task { @MainActor in
        withAnimation(self.animation) { work() }
      }
    }
  }

  extension SharedQueryStateScheduler where Self == AnimationStateScheduler {
    public static func animation(_ animation: Animation) -> Self {
      AnimationStateScheduler(animation: animation)
    }
  }
#endif

// MARK: - UITransactionStateScheduler

#if SwiftNavigation
  public struct UITransactionStateScheduler: SharedQueryStateScheduler {
    let transaction: UITransaction

    public func schedule(work: @escaping @Sendable () -> Void) {
      Task { @MainActor in
        withUITransaction(self.transaction) { work() }
      }
    }
  }

  extension SharedQueryStateScheduler where Self == UITransactionStateScheduler {
    public static func transaction(_ transaction: UITransaction) -> Self {
      UITransactionStateScheduler(transaction: transaction)
    }
  }
#endif
