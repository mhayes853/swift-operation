import FoundationModels

@Generable
public struct UserHumanityGenerable: Hashable, Sendable {
  @Guide(description: "Height in centimeters")
  public var heightCentimeters: Double

  @Guide(description: "Weight in kilograms")
  public var weightKilograms: Double

  @Guide(description: "Age range by decade (20s, 30s, etc.)")
  public var ageRange: String

  @Guide(description: "Gender Identity")
  public var genderIdentity: String

  @Guide(description: "A user-provided assessment of how physically active they are")
  public var activityLevel: String

  @Guide(description: "How often the user exercises")
  public var workoutFrequency: String

  public init(
    heightCentimeters: Double,
    weightKilograms: Double,
    ageRange: String,
    genderIdentity: String,
    activityLevel: String,
    workoutFrequency: String
  ) {
    self.heightCentimeters = heightCentimeters
    self.weightKilograms = weightKilograms
    self.ageRange = ageRange
    self.genderIdentity = genderIdentity
    self.activityLevel = activityLevel
    self.workoutFrequency = workoutFrequency
  }
}
