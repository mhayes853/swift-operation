#if canImport(AlarmKit)
  import AlarmKit
  import IdentifiedCollections
  import ConcurrencyExtras

  // MARK: - AlarmKitStore

  extension ScheduleableAlarm {
    public final actor AlarmKitStore {
      // NB: I'm not sure why Apple hasn't made AlarmManager Sendable, but since they have a static
      // (and presumably nonisolated) shared instance I'm assuming this is safe.
      private nonisolated(unsafe) let manager = AlarmManager.shared

      public init() {}
    }
  }

  // MARK: - Shared

  extension ScheduleableAlarm.AlarmKitStore {
    public static let shared = ScheduleableAlarm.AlarmKitStore()
  }

  // MARK: - Store Conformance

  extension ScheduleableAlarm.AlarmKitStore: ScheduleableAlarm.Store {
    public func requestPermission() async -> Bool {
      (try? await self.manager.requestAuthorization()) == .authorized
    }

    public func schedule(alarm: ScheduleableAlarm) async throws {
      let stopButton = AlarmButton(
        text: "Dismiss",
        textColor: .white,
        systemImageName: "stop.circle"
      )
      let presentationAlert = AlarmPresentation.Alert(title: alarm.title, stopButton: stopButton)
      let attributes = AlarmAttributes<NeverMetadata>(
        presentation: AlarmPresentation(alert: presentationAlert),
        tintColor: .primary
      )
      let configuration = AlarmManager.AlarmConfiguration.alarm(
        schedule: .fixed(alarm.date),
        attributes: attributes
      )

      _ = try await self.manager.schedule(id: alarm.id.rawValue, configuration: configuration)
    }
    
    public func cancel(id: ScheduleableAlarm.ID) async throws {
      try self.manager.cancel(id: id.rawValue)
    }

    public func all() async throws -> [ScheduleableAlarm.ID] {
      try self.manager.alarms.map { ScheduleableAlarm.ID($0.id) }
    }

    public func updates() async -> AsyncStream<[ScheduleableAlarm.ID]> {
      self.manager.alarmUpdates
        .map { alarms in alarms.map { ScheduleableAlarm.ID($0.id) } }
        .eraseToStream()
    }
  }

  // MARK: - NeverMetadata

  private struct NeverMetadata: AlarmMetadata {}
#endif
