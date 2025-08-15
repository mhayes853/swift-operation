import CanIClimbKit
import CustomDump
import GRDB
import StructuredQueriesGRDB
import XCTest

@MainActor
final class ScheduleableAlarmSyncEngineTests: XCTestCase, @unchecked Sendable {
  private var observer: ScheduleableAlarm.SyncEngine!
  private var store: ScheduleableAlarm.MockStore!
  private var database: (any DatabaseWriter)!

  override func setUp() async throws {
    try await super.setUp()
    self.database = try canIClimbDatabase()
    self.store = ScheduleableAlarm.MockStore()
    self.observer = ScheduleableAlarm.SyncEngine(database: self.database, store: self.store)
    try await self.observer.start()
  }

  override func tearDown() async throws {
    try await super.tearDown()
    await self.observer.stop()
  }

  func testSchedulesAlarmsAddedThroughDatabase() async throws {
    let expectation = self.expectation(description: "Alarm scheduled")
    let alarm = ScheduleableAlarm(
      id: ScheduleableAlarm.ID(),
      title: "Blob",
      date: .distantFuture
    )
    await isolate(self.observer) {
      $0.onScheduleNewAlarms = { scheduled in
        guard !scheduled.isEmpty else { return }
        Task { @MainActor in
          expectNoDifference(alarm.id, scheduled[0].0.id)
          expectNoDifference(self.store.all(), Set(scheduled.map { $0.0.id }))
          expectation.fulfill()
        }
      }
    }

    try await self.database.write {
      try ScheduleableAlarmRecord.insert { ScheduleableAlarmRecord(alarm: alarm) }
        .execute($0)
    }

    await self.fulfillment(of: [expectation], timeout: 1)
  }

  func testReplacesScheduledAlarmsViaCancellation() async throws {
    let expectation = self.expectation(description: "Alarm scheduled")
    var a1 = ScheduleableAlarm(
      id: ScheduleableAlarm.ID(),
      title: "Blob",
      date: .distantFuture
    )
    let a2 = ScheduleableAlarm(
      id: ScheduleableAlarm.ID(),
      title: "Blob Jr",
      date: .distantFuture
    )

    try await self.store.schedule(alarm: a1)
    a1.date = .distantFuture - 1000

    await isolate(self.observer) { [a1] in
      $0.onScheduleNewAlarms = { [a1] scheduled in
        guard !scheduled.isEmpty else { return }
        Task { @MainActor in
          expectNoDifference(Set(scheduled.map(\.0.date)), [a1.date, a2.date])
          expectNoDifference(self.store.all(), [a1.id, a2.id])
          expectNoDifference(self.store.cancelCount(for: a1.id), 1)
          expectNoDifference(self.store.cancelCount(for: a2.id), 0)
          expectation.fulfill()
        }
      }
    }

    try await self.database.write { [a1] in
      try ScheduleableAlarmRecord.insert {
        ScheduleableAlarmRecord(alarm: a1)
        ScheduleableAlarmRecord(alarm: a2)
      }
      .execute($0)
    }

    await self.fulfillment(of: [expectation], timeout: 1)
  }

  func testFinishesAlarmsThatHaveBeenRemovedFromStoreOnBeginObserving() async throws {
    let expectation = self.expectation(description: "Alarm scheduled")
    await isolate(self.observer) {
      $0.onScheduleNewAlarms = { scheduled in
        guard !scheduled.isEmpty else { return }
        print(scheduled)
        Task { @MainActor in
          await self.observer.stop()
          expectation.fulfill()
        }
      }
    }

    let alarm = ScheduleableAlarm(
      id: ScheduleableAlarm.ID(),
      title: "Blob Jr",
      date: .distantFuture
    )
    try await self.database.write {
      try ScheduleableAlarmRecord.insert { ScheduleableAlarmRecord(alarm: alarm) }
        .execute($0)
    }
    await self.fulfillment(of: [expectation], timeout: 1)
    await isolate(self.observer) { $0.onScheduleNewAlarms = nil }

    try await self.store.cancel(id: alarm.id)

    try await self.observer.start()

    let alarms = try await self.database.read {
      try ScheduleableAlarmRecord.all.fetchAll($0)
    }
    expectNoDifference(alarms.map(\.id), [alarm.id])
    expectNoDifference(alarms.map(\.status), [.finished])
  }

  func testDoesNotRemoveAlarmsThatCouldNotBeScheduledWhenObservingStarted() async throws {
    let expectation = self.expectation(description: "Alarm scheduled")
    await isolate(self.observer) {
      $0.onScheduleNewAlarms = { scheduled in
        guard !scheduled.isEmpty else { return }
        Task { @MainActor in
          await self.observer.stop()
          expectation.fulfill()
        }
      }
    }

    struct SomeError: Error {}
    self.store.failToScheduleError = SomeError()

    let alarm = ScheduleableAlarm(
      id: ScheduleableAlarm.ID(),
      title: "Blob Jr",
      date: .distantFuture
    )
    try await self.database.write {
      try ScheduleableAlarmRecord.insert { ScheduleableAlarmRecord(alarm: alarm) }
        .execute($0)
    }
    await self.fulfillment(of: [expectation], timeout: 1)
    await isolate(self.observer) { $0.onScheduleNewAlarms = nil }

    try await self.observer.start()

    let alarms = try await self.database.read {
      try ScheduleableAlarmRecord.all.fetchAll($0)
    }

    expectNoDifference(alarms.map(\.id), [alarm.id])
  }

  func testDoesNotScheduleAlarmsThatAreFinished() async throws {
    let expectation = self.expectation(description: "Alarm scheduled")
    expectation.assertForOverFulfill = false
    await isolate(self.observer) {
      $0.onScheduleNewAlarms = { scheduled in
        guard scheduled.isEmpty else { return }
        expectation.fulfill()
      }
    }

    let alarm = ScheduleableAlarmRecord(
      id: ScheduleableAlarm.ID(),
      title: "Blob Jr",
      date: .distantFuture,
      status: .finished
    )
    try await self.database.write {
      try ScheduleableAlarmRecord.insert { alarm }
        .execute($0)
    }
    await self.fulfillment(of: [expectation], timeout: 1)

    let alarmIds = self.store.all()
    expectNoDifference(alarmIds, [])
  }
}
