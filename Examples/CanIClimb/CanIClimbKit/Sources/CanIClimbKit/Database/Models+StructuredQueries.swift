import Foundation
import StructuredQueries
import StructuredQueriesTagged

// MARK: - Human

extension HumanAgeRange: QueryBindable {}
extension HumanGender: QueryBindable {}
extension HumanActivityLevel: QueryBindable {}
extension HumanWorkoutFrequency: QueryBindable {}

// MARK: - Mountain

extension Mountain.Difficulty: QueryBindable {}

extension Mountain {
  public typealias IDRepresentation = Tagged<Self, UUID.BytesRepresentation>
}
