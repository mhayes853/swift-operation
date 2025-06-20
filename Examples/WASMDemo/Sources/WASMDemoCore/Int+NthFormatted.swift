extension Int {
  public var nthFormatted: String {
    let suffix: String
    let lastTwoDigits = self % 100
    let lastDigit = self % 10
    if (11...13).contains(lastTwoDigits) {
      suffix = "th"
    } else {
      switch lastDigit {
      case 1: suffix = "st"
      case 2: suffix = "nd"
      case 3: suffix = "rd"
      default: suffix = "th"
      }
    }
    return "\(self)\(suffix)"
  }
}