import SwiftSyntax
import SwiftSyntaxMacros

extension MacroExpansionContext {
  var parentTypeName: String? {
    for ancestor in self.lexicalContext {
      if let typeDecl = ancestor.as(ActorDeclSyntax.self) {
        return typeDecl.name.trimmedDescription
      }
      if let typeDecl = ancestor.as(ClassDeclSyntax.self) {
        return typeDecl.name.trimmedDescription
      }
      if let structDecl = ancestor.as(StructDeclSyntax.self) {
        return structDecl.name.trimmedDescription
      }
      if let enumDecl = ancestor.as(EnumDeclSyntax.self) {
        return enumDecl.name.trimmedDescription
      }
      if let extDecl = ancestor.as(ExtensionDeclSyntax.self) {
        return extDecl.extendedType.trimmedDescription
      }
    }
    return nil
  }
}
