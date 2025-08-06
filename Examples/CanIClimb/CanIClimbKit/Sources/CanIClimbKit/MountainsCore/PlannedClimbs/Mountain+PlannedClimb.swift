import Foundation
import Tagged
import UUIDV7

// MARK: - PlannedClimb

extension Mountain {
  public struct PlannedClimb: Equatable, Sendable, Identifiable {
    public typealias ID = Tagged<Self, UUIDV7>

    public let id: ID
    public let mountainId: Mountain.ID

    public var targetDate: Date
    public var achievedDate: Date?
    public var alarm: ScheduleableAlarm?

    public init(
      id: Mountain.PlannedClimb.ID,
      mountainId: Mountain.ID,
      targetDate: Date,
      achievedDate: Date?,
      alarm: ScheduleableAlarm?
    ) {
      self.id = id
      self.mountainId = mountainId
      self.targetDate = targetDate
      self.achievedDate = achievedDate
      self.alarm = alarm
    }
  }
}

// MARK: - Mocks

extension Mountain.PlannedClimb {
  public static let mock1 = Self(
    id: ID(),
    mountainId: Mountain.mock1.id,
    targetDate: Date(timeIntervalSince1970: 0),
    achievedDate: nil,
    alarm: nil
  )
}
