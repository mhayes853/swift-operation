import SwiftSyntax

extension TypeSyntax {
  var isOptional: Bool {
    if self.as(OptionalTypeSyntax.self) != nil
      || self.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) != nil
    {
      return true
    }
    if let identifier = self.as(IdentifierTypeSyntax.self) {
      return identifier.name.tokenKind == .identifier("Optional")
    }
    if let member = self.as(MemberTypeSyntax.self) {
      return member.baseType.as(IdentifierTypeSyntax.self)?.name.tokenKind == .identifier("Swift")
        && member.name.tokenKind == .identifier("Optional")
    }
    if let attributed = self.as(AttributedTypeSyntax.self) {
      return attributed.baseType.isOptional
    }
    if let tuple = self.as(TupleTypeSyntax.self), tuple.elements.count == 1 {
      return tuple.elements.first?.type.isOptional ?? false
    }
    return false
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
