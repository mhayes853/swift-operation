import Foundation
import Tagged

// MARK: - ScheduleableAlarm

public struct ScheduleableAlarm: Equatable, Sendable, Identifiable {
  public let id: ScheduleableAlarm.ID
  public var title: LocalizedStringResource
  public var date: Date

  public init(id: ScheduleableAlarm.ID, title: LocalizedStringResource, date: Date) {
    self.id = id
    self.title = title
    self.date = date
  }
}

// MARK: - ID

extension ScheduleableAlarm {
  public typealias ID = Tagged<ScheduleableAlarm, UUID>
}
