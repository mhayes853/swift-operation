#if canImport(AlarmKit)
  import AlarmKit
  import IdentifiedCollections
  import ConcurrencyExtras
  import Tagged

  // MARK: - AlarmKitStore

  extension ScheduleableAlarm {
    public final actor AlarmKitStore {
      // NB: I'm not sure why Apple hasn't made AlarmManager Sendable, but since they have a static
      // (and presumably nonisolated) shared instance I'm assuming this is safe.
      private nonisolated(unsafe) let manager = AlarmManager.shared

      public init() {}
    }
  }

  extension ScheduleableAlarm.AlarmKitStore {
    public static let shared = ScheduleableAlarm.AlarmKitStore()
  }

  extension ScheduleableAlarm.AlarmKitStore: ScheduleableAlarm.Store {
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

    public func all() async throws -> Set<ScheduleableAlarm.ID> {
      try Set(self.manager.alarms.map { ScheduleableAlarm.ID($0.id) })
    }

    private struct NeverMetadata: AlarmMetadata {}
  }

  extension ScheduleableAlarm.AlarmKitStore: ScheduleableAlarm.Authorizer {
    public func requestAuthorization() async throws -> ScheduleableAlarm.AuthorizationStatus {
      try await ScheduleableAlarm.AuthorizationStatus(state: self.manager.requestAuthorization())
    }
    
    public nonisolated func statuses() -> AsyncStream<ScheduleableAlarm.AuthorizationStatus> {
      AsyncStream { continuation in
        let task = Task {
          continuation.yield(
            ScheduleableAlarm.AuthorizationStatus(state: self.manager.authorizationState)
          )
          for await state in self.manager.authorizationUpdates {
            continuation.yield(ScheduleableAlarm.AuthorizationStatus(state: state))
          }
          continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
      }
    }
  }

  // MARK: - AuthorizationStatus

  extension ScheduleableAlarm.AuthorizationStatus {
    public init(state: AlarmManager.AuthorizationState) {
      switch state {
      case .authorized: self = .authorized
      case .denied: self = .unauthorized
      default: self = .notDetermined
      }
    }
  }
#endif
