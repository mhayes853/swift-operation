public enum HumanHeight: Codable, Hashable, Sendable {
  case imperial(feet: Int, inches: Int)
  case metric(centimeters: Double)
}
