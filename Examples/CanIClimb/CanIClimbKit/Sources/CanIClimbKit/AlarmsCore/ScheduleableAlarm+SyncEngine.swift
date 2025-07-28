import Dependencies
import GRDB
import Logging
import StructuredQueriesGRDB

// MARK: - Observer

extension ScheduleableAlarm {
  public final actor SyncEngine {
    private let database: any DatabaseWriter
    private let store: any Store
    private let logger: Logger
    private var task: Task<Void, any Error>?

    private var callbacks: Callbacks?

    public init(
      database: any DatabaseWriter,
      store: any Store = ScheduleableAlarm.defaultStore,
      logger: Logger = Logger(label: "caniclimb.scheduleablealarm.observer")
    ) {
      self.database = database
      self.store = store
      self.logger = logger
    }
  }
}

// MARK: - Callbacks

extension ScheduleableAlarm.SyncEngine {
  public struct Callbacks: Sendable {
    public var onScheduleNewAlarms: (@Sendable ([(ScheduleableAlarm, (any Error)?)]) -> Void)?

    public init(
      onScheduleNewAlarms: (@Sendable ([(ScheduleableAlarm, (any Error)?)]) -> Void)? = nil
    ) {
      self.onScheduleNewAlarms = onScheduleNewAlarms
    }
  }

  public func setCallbacks(_ callbacks: Callbacks?) {
    self.callbacks = callbacks
  }
}

// MARK: - Observing

extension ScheduleableAlarm.SyncEngine {
  public func start() async throws {
    try await self.removeCancelledAlarmsFromDatabase()
    self.logger.info("Performed initial sync with Alarm Store.")

    self.task?.cancel()

    let observation = self.alarmsObservation()
    self.task = Task(priority: .background) { [weak self] in
      for try await alarms in observation {
        guard let self else { return }
        do {
          let results = try await self.store.replaceAll(with: alarms)
          try await self.updateIsScheduled(for: results)
          await self.callbacks?.onScheduleNewAlarms?(results)
          self.logger.info("Scheduled \(results.count) new alarms!")
        } catch {
          self.logger.error("Failed to schedule new alarms: \(String(describing: error)).")
        }
      }
    }
  }

  private func removeCancelledAlarmsFromDatabase() async throws {
    let ids = try await self.store.all()
    try await self.database.write { db in
      try ScheduleableAlarmRecord.delete()
        .where { $0.id.in(ids.map { #bind($0) }).not().and($0.isScheduled.not()) }
        .execute(db)
    }
  }

  private func alarmsObservation() -> some AsyncSequence<[ScheduleableAlarm], any Error> {
    let region = SQLRequest(sql: "SELECT id, title, date FROM ScheduleableAlarms")
    let observation = ValueObservation.tracking(region: region) {
      try ScheduleableAlarmRecord.all.fetchAll($0)
    }
    return observation.values(in: self.database)
      .map { alarms in alarms.map { ScheduleableAlarm(record: $0) } }
  }

  private func updateIsScheduled(
    for results: [(ScheduleableAlarm, (any Error)?)]
  ) async throws {
    try await self.database.write { db in
      for (alarm, error) in results {
        try ScheduleableAlarmRecord.find(#bind(alarm.id))
          .update { $0.isScheduled = error != nil }
          .execute(db)
      }
    }
  }
}

// MARK: - End Observing

extension ScheduleableAlarm.SyncEngine {
  public func stop() {
    self.logger.info("Ending observing.")
    self.task?.cancel()
  }
}

// MARK: - DependencyKey

extension ScheduleableAlarm.SyncEngine: DependencyKey {
  public static var liveValue: ScheduleableAlarm.SyncEngine? {
    #if canImport(AlarmKit)
      @Dependency(\.defaultDatabase) var database
      @Dependency(ScheduleableAlarm.StoreKey.self) var store
      return ScheduleableAlarm.SyncEngine(database: database, store: store)
    #else
      return nil
    #endif
  }
}
