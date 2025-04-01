import XCTest

func XCTAssertThrows<E: Error>(
  _ expression: @autoclosure () async throws -> Void,
  error eType: E.Type,
  file: StaticString = #filePath,
  line: UInt = #line
) async {
  do {
    try await expression()
    XCTFail(
      "Expected expression to throw \(eType), but no error was thrown.",
      file: file,
      line: line
    )
  } catch {
    guard !(error is E) else { return }
    XCTFail(
      "Expected expression to throw \(eType) but got \(type(of: error))",
      file: file,
      line: line
    )
  }
}
