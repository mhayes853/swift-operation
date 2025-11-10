import SwiftSyntax

extension TypeSyntax {
  var isOptional: Bool {
    self.description.contains("?")
      || self.description.starts(with: "Optional<")
      || self.description.contains("!")
  }
}

extension TypeSyntax {
  var typeNameWithoutModifiers: String {
    if let attributed = self.as(AttributedTypeSyntax.self) {
      return attributed.baseType.trimmedDescription
    }
    return self.trimmedDescription
  }
}
