#if canImport(SwiftUI)
  import SwiftUI
#endif

#if SwiftOperationNavigation
  import SwiftNavigation
#endif

// MARK: - SharedOperationStateScheduler

/// A protocol to schedule state updates for ``SharedOperation``.
public protocol SharedOperationStateScheduler: Sendable {
  /// Schedules the state update.
  ///
  /// - Parameter work: The state update.
  func schedule(work: @escaping @Sendable () -> Void)
}

// MARK: - SynchronousStateScheduler

/// A ``SharedOperationStateScheduler`` that schedules its work synchronously.
public struct SynchronousStateScheduler: SharedOperationStateScheduler {
  @inlinable
  public func schedule(work: () -> Void) {
    work()
  }
}

extension SharedOperationStateScheduler where Self == SynchronousStateScheduler {
  /// A ``SharedOperationStateScheduler`` that schedules its work synchronously.
  public static var synchronous: Self { SynchronousStateScheduler() }
}

// MARK: - AnimationStateScheduler

#if canImport(SwiftUI)
  /// A ``SharedOperationStateScheduler`` that schedules its work on the MainActor inside a
  /// `withAnimation` block.
  public struct AnimationStateScheduler: SharedOperationStateScheduler {
    let animation: Animation

    public func schedule(work: @escaping @Sendable () -> Void) {
      Task { @MainActor in
        withAnimation(self.animation) { work() }
      }
    }
  }

  extension SharedOperationStateScheduler where Self == AnimationStateScheduler {
    /// A ``SharedOperationStateScheduler`` that schedules its work on the MainActor inside a
    /// `withAnimation` block.
    ///
    /// - Parameter animation: The animation to use.
    /// - Returns: A scheduler.
    public static func animation(_ animation: Animation) -> Self {
      AnimationStateScheduler(animation: animation)
    }
  }
#endif

// MARK: - UITransactionStateScheduler

#if SwiftOperationNavigation
  /// A ``SharedOperationStateScheduler`` that schedules its work on the MainActor inside a
  /// `withUITransaction` block.
  public struct UITransactionStateScheduler: SharedOperationStateScheduler {
    let transaction: UITransaction

    public func schedule(work: @escaping @Sendable () -> Void) {
      Task { @MainActor in
        withUITransaction(self.transaction) { work() }
      }
    }
  }

  extension SharedOperationStateScheduler where Self == UITransactionStateScheduler {
    /// A ``SharedOperationStateScheduler`` that schedules its work on the MainActor inside a
    /// `withUITransaction` block.
    ///
    /// - Parameter transaction: The `UITransaction` to use.
    /// - Returns: A scheduler.
    public static func transaction(_ transaction: UITransaction) -> Self {
      UITransactionStateScheduler(transaction: transaction)
    }
  }
#endif
