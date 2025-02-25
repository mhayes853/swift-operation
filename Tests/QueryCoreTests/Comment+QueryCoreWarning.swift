@_spi(Warnings) import QueryCore
import Testing

extension Comment {
  static func warning(_ warning: QueryCoreWarning) -> Self {
    Self(rawValue: warning.message)
  }
}
