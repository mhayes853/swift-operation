import IssueReporting

// MARK: - QueryCoreWarning

@_spi(Warnings)
public struct QueryCoreWarning: Sendable, Hashable {
  public let message: String
}

extension QueryCoreWarning: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(message: value)
  }
}

extension QueryCoreWarning: ExpressibleByStringInterpolation {
  public init(stringInterpolation: StringInterpolation) {
    self.init(message: stringInterpolation.description)
  }
}

// MARK: - Report Warning

@_transparent
func reportWarning(
  _ warning: QueryCoreWarning,
  fileID: StaticString = #fileID,
  filePath: StaticString = #filePath,
  line: UInt = #line,
  column: UInt = #column
) {
  reportIssue(
    warning.message,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column
  )
}
