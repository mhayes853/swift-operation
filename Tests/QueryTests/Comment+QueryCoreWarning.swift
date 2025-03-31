@_spi(Warnings) import Query
import Testing

extension Comment {
  static func warning(_ warning: QueryWarning) -> Self {
    Self(rawValue: warning.message)
  }
}
