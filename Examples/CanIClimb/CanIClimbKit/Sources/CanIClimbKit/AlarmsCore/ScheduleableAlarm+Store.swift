import Dependencies
import IdentifiedCollections

// MARK: - Store

extension ScheduleableAlarm {
  public protocol Store: Sendable {
    func requestPermission() async -> Bool

    func schedule(alarm: ScheduleableAlarm) async throws
    func cancel(id: ScheduleableAlarm.ID) async throws
    func all() async throws -> [ScheduleableAlarm.ID]
    func updates() async -> AsyncStream<[ScheduleableAlarm.ID]>
  }

  public enum StoreKey: DependencyKey {
    public static var liveValue: any Store {
      #if os(iOS)
        AlarmKitStore.shared
      #else
        NoopStore()
      #endif
    }
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

    public func all() -> [ScheduleableAlarm.ID] {
      []
    }

    public func updates() -> AsyncStream<[ScheduleableAlarm.ID]> {
      AsyncStream { $0.finish() }
    }
  }
}

// MARK: - MockStore

extension ScheduleableAlarm {
  @MainActor
  public final class MockStore: Store {
    public var isGranted = true
    private var alarms = IdentifiedArrayOf<ScheduleableAlarm>()
    private var continuations = [AsyncStream<[ScheduleableAlarm.ID]>.Continuation]()

    public init() {}

    public func requestPermission() async -> Bool {
      self.isGranted
    }

    public func schedule(alarm: ScheduleableAlarm) async throws {
      self.alarms.append(alarm)
      self.continuations.forEach { $0.yield(self.alarms.map(\.id)) }
    }

    public func cancel(id: ScheduleableAlarm.ID) async throws {
      self.alarms.removeAll(where: { $0.id == id })
      self.continuations.forEach { $0.yield(self.alarms.map(\.id)) }
    }

    public func all() -> [ScheduleableAlarm.ID] {
      self.alarms.map(\.id)
    }

    public func updates() -> AsyncStream<[ScheduleableAlarm.ID]> {
      AsyncStream { continuation in
        continuation.yield(self.alarms.map(\.id))
        self.continuations.append(continuation)
        continuation.onTermination = { _ in
          Task { @MainActor in
            self.continuations.removeAll(where: { $0 == continuation })
          }
        }
      }
    }
  }
}
