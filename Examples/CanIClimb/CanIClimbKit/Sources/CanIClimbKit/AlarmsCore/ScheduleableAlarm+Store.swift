import Dependencies
import IdentifiedCollections
import Query
import Tagged

// MARK: - Store

extension ScheduleableAlarm {
  public protocol Store: Sendable {
    func requestPermission() async -> Bool

    func schedule(alarm: ScheduleableAlarm) async throws
    func cancel(id: ScheduleableAlarm.ID) async throws
    func all() async throws -> Set<ScheduleableAlarm.ID>
  }

  public static var defaultStore: any Store {
    #if os(iOS)
      AlarmKitStore.shared
    #else
      NoopStore()
    #endif
  }

  public enum StoreKey: DependencyKey {
    public static var liveValue: any Store {
      ScheduleableAlarm.defaultStore
    }
  }
}

extension ScheduleableAlarm.Store {
  public func replaceAll(
    with alarms: some Sequence<ScheduleableAlarm>
  ) async throws -> [(ScheduleableAlarm, (any Error)?)] {
    try await withThrowingTaskGroup { group in
      for id in try await self.all() {
        group.addTask { try await self.cancel(id: id) }
      }
    }
    return await withTaskGroup(of: (ScheduleableAlarm, (any Error)?).self) { group in
      for alarm in alarms {
        group.addTask {
          do {
            try await self.schedule(alarm: alarm)
            return (alarm, nil)
          } catch {
            return (alarm, error)
          }
        }
      }
      return await group.reduce(into: []) { $0.append($1) }
    }
  }
}

extension ScheduleableAlarm {
  public struct ReplaceAllResult: Equatable, Sendable {
    public let successfullyScheduledAlarms: [ScheduleableAlarm]
  }
}

// MARK: - NoopStore

extension ScheduleableAlarm {
  public final class NoopStore: Store {
    public init() {}

    public func requestPermission() async -> Bool {
      true
    }

    public func schedule(alarm: ScheduleableAlarm) async throws {
    }

    public func cancel(id: ScheduleableAlarm.ID) async throws {
    }

    public func all() -> Set<ScheduleableAlarm.ID> {
      []
    }
  }
}

// MARK: - MockStore

extension ScheduleableAlarm {
  @MainActor
  public final class MockStore: Store {
    public var isGranted = true
    public var failToScheduleError: (any Error)?
    private var alarms = Set<ScheduleableAlarm.ID>()
    private var cancelCounts = [ScheduleableAlarm.ID: Int]()

    public init() {}

    public func cancelCount(for id: ScheduleableAlarm.ID) -> Int {
      self.cancelCounts[id, default: 0]
    }

    public func requestPermission() async -> Bool {
      self.isGranted
    }

    public func schedule(alarm: ScheduleableAlarm) async throws {
      if let error = self.failToScheduleError {
        throw error
      }
      self.alarms.insert(alarm.id)
    }

    public func cancel(id: ScheduleableAlarm.ID) async throws {
      self.alarms.remove(id)
      self.cancelCounts[id, default: 0] += 1
    }

    public func all() -> Set<ScheduleableAlarm.ID> {
      self.alarms
    }
  }
}

// MARK: - Permissions Mutation

extension ScheduleableAlarm {
  public static let requestPermissionMutation = RequestPermissionMutation()

  public struct RequestPermissionMutation: MutationRequest, Hashable {
    public typealias Arguments = Void

    public func mutate(
      with arguments: Void,
      in context: QueryContext,
      with continuation: QueryContinuation<Bool>
    ) async -> Bool {
      @Dependency(ScheduleableAlarm.StoreKey.self) var store
      return await store.requestPermission()
    }
  }
}
