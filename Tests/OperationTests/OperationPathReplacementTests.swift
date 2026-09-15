import CustomDump
import Operation
import Testing

@Suite
struct `OperationPath Replacement tests` {
  @Test(arguments: [OperationPath(), OperationPath("original"), OperationPath(["original"])])
  func `Replacement Preserves Every Element`(original: OperationPath) {
    let replacement = [OperationPath.Element("first"), OperationPath.Element("second")]
    for lowerBound in original.startIndex...original.endIndex {
      for upperBound in lowerBound...original.endIndex {
        var path = original
        var expected = Array(original)
        let range = lowerBound..<upperBound

        path.replaceSubrange(range, with: replacement)
        expected.replaceSubrange(range, with: replacement)

        expectNoDifference(Array(path), expected)
      }
    }
  }
}
