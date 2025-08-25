import IssueReporting

// MARK: - QueryWarning

@_spi(Warnings)
public struct QueryWarning: Sendable, Hashable {
  public let message: String
}

extension QueryWarning: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(message: value)
  }
}

extension QueryWarning: ExpressibleByStringInterpolation {
  public init(stringInterpolation: StringInterpolation) {
    self.init(message: stringInterpolation.description)
  }
}

// MARK: - Report Warning

@_transparent
@_spi(Warnings) public func reportWarning(
  _ warning: QueryWarning,
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
