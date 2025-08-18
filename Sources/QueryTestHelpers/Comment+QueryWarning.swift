@_spi(Warnings) import QueryCore
import Testing

@_spi(Warnings)
extension Comment {
  public static func warning(_ warning: QueryWarning) -> Self {
    Self(rawValue: warning.message)
  }
}
