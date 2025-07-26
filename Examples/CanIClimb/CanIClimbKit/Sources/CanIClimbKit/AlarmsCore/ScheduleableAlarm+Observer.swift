import Dependencies
import GRDB
import Logging
import StructuredQueriesGRDB

// MARK: - Observer

extension ScheduleableAlarm {
  public final actor Observer {
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

    isolated deinit {
      self.endObserving()
    }
  }
}

// MARK: - Callbacks

extension ScheduleableAlarm.Observer {
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

extension ScheduleableAlarm.Observer {
  public func beginObserving() async throws {
    try await self.removeCancelledAlarmsFromDatabase()
    self.logger.info("Performed initial sync with Alarm Store.")

    self.task?.cancel()

    self.task = Task {
      for try await alarms in self.alarmsObservation() {
        do {
          let results = try await self.store.replaceAll(with: alarms)
          try await self.updateIsScheduled(for: results)
          self.callbacks?.onScheduleNewAlarms?(results)
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

extension ScheduleableAlarm.Observer {
  public func endObserving() {
    self.logger.info("Ending observing.")
    self.task?.cancel()
  }
}
