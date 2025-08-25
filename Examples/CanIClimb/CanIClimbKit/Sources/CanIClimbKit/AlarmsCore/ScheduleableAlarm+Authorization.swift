import Dependencies
import Operation
import Sharing
import SwiftUI

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
  public protocol Authorizer: AnyObject, Sendable {
    associatedtype Statuses: AsyncSequence<ScheduleableAlarm.AuthorizationStatus, Never>

    func requestAuthorization() async throws -> AuthorizationStatus
    func statuses() -> Statuses
  }

  public enum AuthorizerKey: DependencyKey {
    public static var liveValue: any Authorizer {
      #if canImport(AlarmKit)
        ScheduleableAlarm.AlarmKitStore.shared
      #else
        ScheduleableAlarm.MockAuthorizer()
      #endif
    }
  }
}

// MARK: - MockAuthorizer

extension ScheduleableAlarm {
  @MainActor
  public final class MockAuthorizer: ScheduleableAlarm.Authorizer {
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

    public func requestAuthorization() async throws -> ScheduleableAlarm.AuthorizationStatus {
      self.status = self.statusOnRequest
      return self.statusOnRequest
    }

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
}

// MARK: - SharedReaderKey

extension SharedReaderKey where Self == ScheduleableAlarm.AuthorizationStatus.UpdatesKey.Default {
  public static var alarmsAuthorization: Self {
    Self[ScheduleableAlarm.AuthorizationStatus.UpdatesKey(), default: .notDetermined]
  }
}

extension ScheduleableAlarm.AuthorizationStatus {
  public struct UpdatesKey: SharedReaderKey {
    private let authorizer: any ScheduleableAlarm.Authorizer

    public init() {
      @Dependency(ScheduleableAlarm.AuthorizerKey.self) var authorizer
      self.authorizer = authorizer
    }

    public typealias Value = ScheduleableAlarm.AuthorizationStatus

    public struct ID: Hashable {
      fileprivate let inner: ObjectIdentifier
    }

    public var id: ID {
      ID(inner: ObjectIdentifier(self.authorizer))
    }

    public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
      continuation.resumeReturningInitialValue()
    }

    public func subscribe(
      context: LoadContext<Value>,
      subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
      let task = Task.immediate {
        for await status in self.authorizer.statuses() {
          withAnimation { subscriber.yield(status) }
        }
      }
      return SharedSubscription { task.cancel() }
    }
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
