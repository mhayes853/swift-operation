import Dependencies
import Query
import Sharing

// MARK: - AuthorizationStatus

extension ScheduleableAlarm {
  public enum AuthorizationStatus: Hashable, Sendable {
    case notDetermined
    case authorized
    case unauthorized
  }
}

// MARK: - Authorizer

extension ScheduleableAlarm {
  public protocol Authorizer: Sendable {
    func requestAuthorization() async throws -> AuthorizationStatus
  }

  public enum AuthorizerKey: DependencyKey {
    public static var liveValue: any Authorizer {
      #if canImport(AlarmKit)
        ScheduleableAlarm.AlarmKitStore.shared
      #else
        ScheduleableAlarm.MockAuthorization()
      #endif
    }
  }
}

// MARK: - AuthorizationObserver

extension ScheduleableAlarm.AuthorizationStatus {
  public protocol Observer: Sendable, AnyObject {
    associatedtype Statuses: AsyncSequence<ScheduleableAlarm.AuthorizationStatus, Never>

    func statuses() -> Statuses
  }

  public enum ObserverKey: DependencyKey {
    public static var liveValue: any Observer {
      #if canImport(AlarmKit)
        ScheduleableAlarm.AlarmKitStore.shared
      #else
        ScheduleableAlarm.MockAuthorization()
      #endif
    }
  }
}

// MARK: - MockAuthorization

extension ScheduleableAlarm {
  @MainActor
  public final class MockAuthorization {
    public var status = AuthorizationStatus.notDetermined {
      didSet {
        for continuation in continuations {
          continuation.yield(self.status)
        }
      }
    }
    private var continuations = Set<AsyncStream<AuthorizationStatus>.Continuation>()

    public var statusOnRequest = AuthorizationStatus.authorized

    public nonisolated init() {}
  }
}

extension ScheduleableAlarm.MockAuthorization: ScheduleableAlarm.Authorizer {
  public func requestAuthorization() async throws -> ScheduleableAlarm.AuthorizationStatus {
    self.status = self.statusOnRequest
    return self.statusOnRequest
  }
}

extension ScheduleableAlarm.MockAuthorization: ScheduleableAlarm.AuthorizationStatus.Observer {
  public nonisolated func statuses() -> AsyncStream<ScheduleableAlarm.AuthorizationStatus> {
    AsyncStream { continuation in
      Task { @MainActor in
        continuation.yield(self.status)
        self.continuations.insert(continuation)
      }
      continuation.onTermination = { [weak self] _ in
        Task { @MainActor in self?.continuations.remove(continuation) }
      }
    }
  }
}

// MARK: - SharedReaderKey

extension SharedReaderKey where Self == ScheduleableAlarm.AuthorizationStatus.UpdatesKey.Default {
  public static var alarmsAuthorization: Self {
    Self[ScheduleableAlarm.AuthorizationStatus.UpdatesKey(), default: .notDetermined]
  }
}

extension ScheduleableAlarm.AuthorizationStatus {
  public struct UpdatesKey {
    private let observer: any Observer

    public init() {
      @Dependency(ScheduleableAlarm.AuthorizationStatus.ObserverKey.self) var observer
      self.observer = observer
    }
  }
}

extension ScheduleableAlarm.AuthorizationStatus.UpdatesKey: SharedReaderKey {
  public typealias Value = ScheduleableAlarm.AuthorizationStatus

  public struct ID: Hashable {
    fileprivate let inner: ObjectIdentifier
  }

  public var id: ID {
    ID(inner: ObjectIdentifier(self.observer))
  }

  public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
    continuation.resumeReturningInitialValue()
  }

  public func subscribe(
    context: LoadContext<Value>,
    subscriber: SharedSubscriber<Value>
  ) -> SharedSubscription {
    let task = Task.immediate {
      for await status in self.observer.statuses() {
        subscriber.yield(status)
      }
    }
    return SharedSubscription { task.cancel() }
  }
}

// MARK: - Query

extension ScheduleableAlarm {
  public static let requestAuthorizationMutation = RequestAuthorizationMutation()

  public struct RequestAuthorizationMutation: MutationRequest, Hashable {
    public typealias Arguments = Void

    public func mutate(
      with arguments: Void,
      in context: QueryContext,
      with continuation: QueryContinuation<AuthorizationStatus>
    ) async throws -> AuthorizationStatus {
      @Dependency(ScheduleableAlarm.AuthorizerKey.self) var authorizer
      return try await authorizer.requestAuthorization()
    }
  }
}
