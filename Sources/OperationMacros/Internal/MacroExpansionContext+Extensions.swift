import SwiftSyntax
import SwiftSyntaxMacros

extension MacroExpansionContext {
  var parentTypeName: String? {
    self.parentTypeToken?.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var parentTypeToken: TokenSyntax? {
    for ancestor in self.lexicalContext {
      if let typeDecl = ancestor.as(ActorDeclSyntax.self) {
        return typeDecl.name
      }
      if let typeDecl = ancestor.as(ClassDeclSyntax.self) {
        return typeDecl.name
      }
      if let structDecl = ancestor.as(StructDeclSyntax.self) {
        return structDecl.name
      }
      if let enumDecl = ancestor.as(EnumDeclSyntax.self) {
        return enumDecl.name
      }
      if let extDecl = ancestor.as(ExtensionDeclSyntax.self),
        let extendedType = extDecl.extendedType.as(IdentifierTypeSyntax.self)
      {
        return extendedType.name
      }
    }
    return nil
  }
}
