public struct NumberFact: Hashable, Sendable {
  public let number: Int
  public let content: String

  public init(number: Int, content: String) {
    self.number = number
    self.content = content
  }
}