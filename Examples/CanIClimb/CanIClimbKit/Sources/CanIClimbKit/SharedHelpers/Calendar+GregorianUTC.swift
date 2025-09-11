import Foundation

extension Calendar {
  /// A gregorian calendar with UTC time zone.
  public static let gregorianUTC: Self = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()
}
