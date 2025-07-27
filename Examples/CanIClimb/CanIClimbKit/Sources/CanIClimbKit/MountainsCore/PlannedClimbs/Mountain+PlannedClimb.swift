import Tagged
import UUIDV7

// MARK: - PlannedClimb

extension Mountain {
  public typealias PlannedClimb = CachedPlannedClimbRecord
}

// MARK: - ID

extension Mountain.PlannedClimb {
  public typealias ID = Tagged<Self, UUIDV7>
}
