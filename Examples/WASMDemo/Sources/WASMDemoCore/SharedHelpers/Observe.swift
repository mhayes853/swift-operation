import Observation
import Synchronization

// MARK: - Observe

@MainActor
@discardableResult
public func observe(_ apply: @escaping @MainActor () -> Void) -> ObserveToken {
  let token = ObserveToken()
  onChange(token: token, apply: apply)
  return token
}

@MainActor
private func onChange(token: ObserveToken, apply: @escaping @MainActor () -> Void) {
  guard !token.isCancelled else { return }
  withObservationTracking {
    apply()
  } onChange: { [weak token] in
    Task { @MainActor in
      guard let token else { return }
      onChange(token: token, apply: apply)
    }
  }
}

// MARK: - ObserveToken

public final class ObserveToken: Sendable {
  private let _isCancelled = Mutex(false)

  public var isCancelled: Bool {
    self._isCancelled.withLock { $0 }
  }

  init() {}

  deinit {
    self.cancel()
  }

  public func cancel() {
    self._isCancelled.withLock { $0 = true }
  }

  public func store(in set: inout Set<ObserveToken>) {
    set.insert(self)
  }
}

extension ObserveToken: Hashable {
  public static func == (lhs: ObserveToken, rhs: ObserveToken) -> Bool {
    lhs === rhs
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
