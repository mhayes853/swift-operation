// MARK: - ModifierSetupScope

extension OperationContext {
  /// The setup pass that a modifier is currently being set up in.
  ///
  /// Most modifiers can ignore this. It matters when a modifier claims something that belongs to
  /// the operation for its entire lifetime, rather than to a single run.
  ///
  /// ```swift
  /// public func setup(context: inout OperationContext, using operation: Operation) {
  ///   // A transform is set up on every run, so claiming this each time would hand the
  ///   // connection to whichever run set up last.
  ///   if context.modifierSetupScope == .runtimeInitialSetup {
  ///     context.connectionPool = ConnectionPool()
  ///   }
  ///   operation.setup(context: &context)
  /// }
  /// ```
  public var modifierSetupScope: ModifierSetupScope {
    get { self[ModifierSetupScopeKey.self] }
    set { self[ModifierSetupScopeKey.self] = newValue }
  }

  private enum ModifierSetupScopeKey: Key {
    static var defaultValue: ModifierSetupScope { .runtimeInitialSetup }
  }

  /// A pass in which an ``OperationModifier`` is set up.
  public enum ModifierSetupScope: Hashable, Sendable {
    /// An ``OperationRunner``'s one-time setup of the operation it was created with.
    ///
    /// Modifiers write their configuration before setting up the operation they're attached to,
    /// so the ones applied closest to the operation win. This is why an operation's own
    /// ``OperationRequest/retry(limit:)`` beats the one `OperationClient` applies by default.
    case runtimeInitialSetup

    /// The setup of the modifiers that the ``OperationTransform``s in scope apply to a single run.
    ///
    /// This pass stops at the operation itself, which was already set up during
    /// ``runtimeInitialSetup``. A transform's configuration therefore lands on top of the
    /// operation's own, and wins.
    case operationRun
  }
}
