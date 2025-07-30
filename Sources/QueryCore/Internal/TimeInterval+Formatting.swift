import Foundation

extension TimeInterval {
  func durationFormatted() -> String {
    self != 1 ? "\(self) secs" : "1.0 sec"
  }
}
