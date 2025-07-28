import Foundation
import StructuredQueries
import StructuredQueriesTagged
import UUIDV7

// MARK: - Human

extension HumanAgeRange: QueryBindable {}
extension HumanGender: QueryBindable {}
extension HumanActivityLevel: QueryBindable {}
extension HumanWorkoutFrequency: QueryBindable {}

// MARK: - ApplicationLaunch

extension ApplicationLaunch {
  public typealias IDRepresentation = Tagged<Self, UUIDV7.BytesRepresentation>
}
