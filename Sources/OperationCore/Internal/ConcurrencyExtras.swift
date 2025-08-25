// NB: This is needed because ConcurrencyExtras seems to have some symbol issues with WASM.

// MARK: - Task Mega Yield

extension Task where Success == Never, Failure == Never {
  package static func megaYield(count: Int = 20) async {
    for _ in 0..<count {
      await Task<Void, Never>.detached(priority: .background) { await Task.yield() }.value
    }
  }
}

// MARK: - Task Never

extension Task where Failure == Never {
  package static func never() async throws -> Success {
    let stream = AsyncStream<Success> { _ in }
    for await element in stream {
      return element
    }
    throw _Concurrency.CancellationError()
  }
}

extension Task where Success == Never, Failure == Never {
  package static func never() async throws {
    let stream = AsyncStream<Success> { _ in }
    for await _ in stream {}
    throw _Concurrency.CancellationError()
  }
}

// MARK: - Task Cancellable Value

extension Task where Failure == Never {
  package var cancellableValue: Success {
    get async {
      await withTaskCancellationHandler {
        await self.value
      } onCancel: {
        self.cancel()
      }
    }
  }
}

extension Task where Failure == Error {
  package var cancellableValue: Success {
    get async throws {
      try await withTaskCancellationHandler {
        try await self.value
      } onCancel: {
        self.cancel()
      }
    }
  }
}

// MARK: - AnyHashableSendable

package struct AnyHashableSendable: Hashable, Sendable {
  package let base: any Hashable & Sendable

  @_disfavoredOverload
  package init(_ base: any Hashable & Sendable) {
    self.init(base)
  }

  package init(_ base: some Hashable & Sendable) {
    if let base = base as? AnyHashableSendable {
      self = base
    } else {
      self.base = base
    }
  }

  package static func == (lhs: Self, rhs: Self) -> Bool {
    AnyHashable(lhs.base) == AnyHashable(rhs.base)
  }

  package func hash(into hasher: inout Hasher) {
    hasher.combine(base)
  }
}

extension AnyHashableSendable: CustomDebugStringConvertible {
  package var debugDescription: String {
    "AnyHashableSendable(" + String(reflecting: base) + ")"
  }
}

extension AnyHashableSendable: CustomReflectable {
  package var customMirror: Mirror {
    Mirror(self, children: ["value": base])
  }
}

extension AnyHashableSendable: CustomStringConvertible {
  package var description: String {
    String(describing: base)
  }
}

extension AnyHashableSendable: _HasCustomAnyHashableRepresentation {
  package func _toCustomAnyHashable() -> AnyHashable? {
    base as? AnyHashable
  }
}

extension AnyHashableSendable: ExpressibleByBooleanLiteral {
  package init(booleanLiteral value: Bool) {
    self.init(value)
  }
}

extension AnyHashableSendable: ExpressibleByFloatLiteral {
  package init(floatLiteral value: Double) {
    self.init(value)
  }
}

extension AnyHashableSendable: ExpressibleByIntegerLiteral {
  package init(integerLiteral value: Int) {
    self.init(value)
  }
}

extension AnyHashableSendable: ExpressibleByStringLiteral {
  package init(stringLiteral value: String) {
    self.init(value)
  }
}

// MARK: - Result

extension Result {
  @_transparent
  package init(catching body: () async throws(Failure) -> Success) async {
    do {
      self = .success(try await body())
    } catch {
      self = .failure(error)
    }
  }
}
