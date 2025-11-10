extension StringProtocol {
  var firstCharacterCapitalized: String {
    guard let first else { return "" }
    return first.uppercased() + self.dropFirst()
  }
}
