import CanIClimbKit
import CustomDump
import Foundation
import Testing

@Suite("NumericHealthSamples+Request tests")
struct NumericHealthSamplesRequestTests {
  @Test(
    "From Query",
    arguments: [
      ("last 2 weeks", DateInterval(start: .testNow - twoWeeks, duration: twoWeeks)),
      ("last 1 week", DateInterval(start: .testNow - oneWeek, duration: oneWeek)),
      ("last 1 weeks", DateInterval(start: .testNow - oneWeek, duration: oneWeek)),
      ("last week", DateInterval(start: .testNow - oneWeek, duration: oneWeek)),
      ("last 10 days", DateInterval(start: .testNow - tenDays, duration: tenDays)),
      ("last 1 days", DateInterval(start: .testNow - oneDay, duration: oneDay)),
      ("last 1 day", DateInterval(start: .testNow - oneDay, duration: oneDay)),
      ("last day", DateInterval(start: .testNow - oneDay, duration: oneDay)),
      (
        "last 1 month",
        DateInterval(start: Date(staticISO8601: "2025-08-11T12:34:56+0000"), end: .testNow)
      ),
      (
        "last 1 months",
        DateInterval(start: Date(staticISO8601: "2025-08-11T12:34:56+0000"), end: .testNow)
      ),
      (
        "last month",
        DateInterval(start: Date(staticISO8601: "2025-08-11T12:34:56+0000"), end: .testNow)
      ),
      (
        "last 3 months",
        DateInterval(start: Date(staticISO8601: "2025-06-11T12:34:56+0000"), end: .testNow)
      ),
      ("djkldkljlkjld", DateInterval(start: .testNow, end: .testNow))
    ]
  )
  func fromQuery(query: String, expected: DateInterval) {
    let request = NumericHealthSamples.Request(query: query, now: .testNow, calendar: .gregorianUTC)
    expectNoDifference(request, NumericHealthSamples.Request(interval: expected))
  }
}

private let oneDay = TimeInterval(24 * 60 * 60)
private let tenDays = TimeInterval(10 * 24 * 60 * 60)
private let twoWeeks = TimeInterval(14 * 24 * 60 * 60)
private let oneWeek = TimeInterval(7 * 24 * 60 * 60)

extension Date {
  fileprivate static let testNow = Date(staticISO8601: "2025-09-11T12:34:56+0000")
}
