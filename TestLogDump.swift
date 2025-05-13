import Foundation

// Helper script to diagnose hanging tests.

let log = try! String(contentsOfFile: "TestLog.txt", encoding: .utf8)

// Regex patterns
let testStartedPattern = #"Test "(.*?)" started"#
let testPassedPattern = #"Test "(.*?)" passed after"#
let testFailedPattern = #"Test "(.*?)" failed after"#
let testKnownIssuePattern = #"Test "(.*?)" passed after .*? with \d+ known issue"#

// Match helper
func match(_ pattern: String, in text: String) -> [String] {
  let regex = try! NSRegularExpression(pattern: pattern, options: [])
  let range = NSRange(text.startIndex..<text.endIndex, in: text)
  return regex.matches(in: text, options: [], range: range)
    .compactMap {
      guard let matchRange = Range($0.range(at: 1), in: text) else { return nil }
      return String(text[matchRange])
    }
}

// Extract data
let startedTests = Set(match(testStartedPattern, in: log))
let passedTests = Set(match(testPassedPattern, in: log))
let knownIssues = Set(match(testKnownIssuePattern, in: log))
let failedTests = Set(match(testFailedPattern, in: log))
let finishedTests = passedTests.union(knownIssues).union(failedTests)
let stillRunning = startedTests.subtracting(finishedTests)

print("🧪 Test Summary")
print("==============")
print("Total tests started: \(startedTests.count)")
print("✅ Passed: \(passedTests.count)")
print("⚠️ Known issues: \(knownIssues.count)")
print("❌ Failed: \(failedTests.count)")
print("⏳ Still running: \(stillRunning.count)")
if !stillRunning.isEmpty {
  print("\nStill Running Tests:")
  stillRunning.sorted().forEach { print(" - \($0)") }
}
if !failedTests.isEmpty {
  print("\nFailed Tests:")
  failedTests.sorted().forEach { print(" - \($0)") }
}
