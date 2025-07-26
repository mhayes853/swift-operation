import CanIClimbKit
import CustomDump
import GRDB
import StructuredQueriesGRDB
import XCTest

@MainActor
final class ScheduleableAlarmObserverTests: XCTestCase, @unchecked Sendable {
  private var observer: ScheduleableAlarm.Observer!
  private var store: ScheduleableAlarm.MockStore!
  private var database: (any DatabaseWriter)!

  override func setUp() async throws {
    try await super.setUp()
    self.database = try canIClimbDatabase()
    self.store = ScheduleableAlarm.MockStore()
    self.observer = ScheduleableAlarm.Observer(database: self.database, store: self.store)
    try await self.observer.beginObserving()
  }

  func testSchedulesAlarmsAddedThroughDatabase() async throws {
    let expectation = self.expectation(description: "Alarm scheduled")
    let alarm = ScheduleableAlarm(
      id: ScheduleableAlarm.ID(),
      title: "Blob",
      date: .distantFuture
    )
    await self.observer.setCallbacks(
      ScheduleableAlarm.Observer.Callbacks { scheduled in
        guard !scheduled.isEmpty else { return }
        Task { @MainActor in
          expectNoDifference(alarm.id, scheduled[0].0.id)
          expectNoDifference(self.store.all(), Set(scheduled.map { $0.0.id }))
          expectation.fulfill()
        }
      }
    )

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

    await self.observer.setCallbacks(
      ScheduleableAlarm.Observer.Callbacks { [a1] scheduled in
        guard !scheduled.isEmpty else { return }
        Task { @MainActor in
          expectNoDifference(Set(scheduled.map(\.0.date)), [a1.date, a2.date])
          expectNoDifference(self.store.all(), [a1.id, a2.id])
          expectNoDifference(self.store.cancelCount(for: a1.id), 1)
          expectNoDifference(self.store.cancelCount(for: a2.id), 0)
          expectation.fulfill()
        }
      }
    )

    try await self.database.write { [a1] in
      try ScheduleableAlarmRecord.insert {
        ScheduleableAlarmRecord(alarm: a1)
        ScheduleableAlarmRecord(alarm: a2)
      }
      .execute($0)
    }

    await self.fulfillment(of: [expectation], timeout: 1)
  }

  func testRemovesAlarmsThatHaveBeenRemovedFromStoreOnBeginObserving() async throws {
    let expectation = self.expectation(description: "Alarm scheduled")
    await self.observer.setCallbacks(
      ScheduleableAlarm.Observer.Callbacks { scheduled in
        guard !scheduled.isEmpty else { return }
        Task { @MainActor in
          await self.observer.endObserving()
          expectation.fulfill()
        }
      }
    )

    let alarm = ScheduleableAlarm(
      id: ScheduleableAlarm.ID(),
      title: "Blob Jr",
      date: .distantFuture
    )
    try await self.database.write {
      try ScheduleableAlarmRecord.insert { ScheduleableAlarmRecord(alarm: alarm) }.execute($0)
    }
    await self.fulfillment(of: [expectation], timeout: 1)
    await self.observer.setCallbacks(nil)

    try await self.store.cancel(id: alarm.id)

    try await self.observer.beginObserving()

    let alarms = try await self.database.read {
      try ScheduleableAlarmRecord.all.fetchAll($0)
    }
    expectNoDifference(alarms, [])
  }

  func testDoesNotRemoveAlarmsThatCouldNotBeScheduledWhenObservingStarted() async throws {
    let expectation = self.expectation(description: "Alarm scheduled")
    await self.observer.setCallbacks(
      ScheduleableAlarm.Observer.Callbacks { scheduled in
        guard !scheduled.isEmpty else { return }
        Task { @MainActor in
          await self.observer.endObserving()
          expectation.fulfill()
        }
      }
    )

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
    await self.observer.setCallbacks(nil)

    try await self.observer.beginObserving()

    let alarms = try await self.database.read {
      try ScheduleableAlarmRecord.all.fetchAll($0)
    }

    expectNoDifference(alarms.map(\.id), [alarm.id])
  }
}
