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
  public typealias IDRepresentation = Tagged<Self, UUID.BytesRepresentation>
}

// MARK: - ApplicationLaunchID

extension ApplicationLaunchID {
  public typealias Representation = Tagged<_ApplicationLaunchIDTag, UUIDV7.BytesRepresentation>
}
