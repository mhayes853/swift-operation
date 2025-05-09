#if canImport(SwiftUI)
  import SwiftUI
#endif

#if SwiftNavigation
  import SwiftNavigation
#endif

// MARK: - SharedQueryStateScheduler

/// A protocol to schedule state updates for ``SharedQuery``.
public protocol SharedQueryStateScheduler: Sendable {
  /// Schedules the state update.
  ///
  /// - Parameter work: The state update.
  func schedule(work: @escaping @Sendable () -> Void)
}

// MARK: - SynchronousStateScheduler

/// A ``SharedQueryStateScheduler`` that schedules its work synchronously.
public struct SynchronousStateScheduler: SharedQueryStateScheduler {
  @inlinable
  public func schedule(work: () -> Void) {
    work()
  }
}

extension SharedQueryStateScheduler where Self == SynchronousStateScheduler {
  /// A ``SharedQueryStateScheduler`` that schedules its work synchronously.
  public static var synchronous: Self { SynchronousStateScheduler() }
}

// MARK: - AnimationStateScheduler

#if canImport(SwiftUI)
  /// A ``SharedQueryStateScheduler`` that schedules its work on the MainActor inside a
  /// `withAnimation` block.
  public struct AnimationStateScheduler: SharedQueryStateScheduler {
    let animation: Animation

    public func schedule(work: @escaping @Sendable () -> Void) {
      Task { @MainActor in
        withAnimation(self.animation) { work() }
      }
    }
  }

  extension SharedQueryStateScheduler where Self == AnimationStateScheduler {
    /// A ``SharedQueryStateScheduler`` that schedules its work on the MainActor inside a
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

#if SwiftNavigation
  /// A ``SharedQueryStateScheduler`` that schedules its work on the MainActor inside a
  /// `withUITransaction` block.
  public struct UITransactionStateScheduler: SharedQueryStateScheduler {
    let transaction: UITransaction

    public func schedule(work: @escaping @Sendable () -> Void) {
      Task { @MainActor in
        withUITransaction(self.transaction) { work() }
      }
    }
  }

  extension SharedQueryStateScheduler where Self == UITransactionStateScheduler {
    /// A ``SharedQueryStateScheduler`` that schedules its work on the MainActor inside a
    /// `withUITransaction` block.
    ///
    /// - Parameter transaction: The `UITransaction` to use.
    /// - Returns: A scheduler.
    public static func transaction(_ transaction: UITransaction) -> Self {
      UITransactionStateScheduler(transaction: transaction)
    }
  }
#endif
