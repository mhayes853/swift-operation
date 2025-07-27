import Foundation
import StructuredQueries
import StructuredQueriesTagged
import UUIDV7

// MARK: - Human

extension HumanAgeRange: QueryBindable {}
extension HumanGender: QueryBindable {}
extension HumanActivityLevel: QueryBindable {}
extension HumanWorkoutFrequency: QueryBindable {}

// MARK: - Mountain

extension Mountain.ClimbingDifficulty: QueryBindable {}

extension Mountain {
  public typealias IDRepresentation = Tagged<Self, UUIDV7.BytesRepresentation>
}

extension Mountain.PlannedClimb {
  public typealias IDRepresentation = Tagged<Self, UUIDV7.BytesRepresentation>
}

// MARK: - ApplicationLaunch

extension ApplicationLaunch {
  public typealias IDRepresentation = Tagged<Self, UUIDV7.BytesRepresentation>
}

// MARK: - ScheduleableAlarm

extension ScheduleableAlarm {
  public typealias IDRepresentation = Tagged<ScheduleableAlarm, UUID.BytesRepresentation>
}
