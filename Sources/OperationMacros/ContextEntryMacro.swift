import SwiftSyntax
import SwiftSyntaxMacros

public enum ContextEntryMacro: PeerMacro, AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [SwiftSyntax.DeclSyntax] {
    let extensionType = context.lexicalContext.first?
      .as(ExtensionDeclSyntax.self)?
      .extendedType
      .as(IdentifierTypeSyntax.self)

    guard extensionType?.name.text == "OperationContext" else {
      throw MacroExpansionErrorMessage(
        "@ContextEntry can only be used inside an extension of OperationContext."
      )
    }

    guard let variableDecl = declaration.as(VariableDeclSyntax.self),
      let binding = variableDecl.bindings.first,
      binding.accessorBlock == nil
    else {
      throw MacroExpansionErrorMessage("@ContextEntry can only be applied to a stored property.")
    }
    guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
      throw MacroExpansionErrorMessage("@ContextEntry must be applied to a simple identifier.")
    }

    let name = identifierPattern.identifier.text
    let keyTypeName = "__Key_\(name)"
    let isExplicitlyOptionalType = binding.typeAnnotation?.type.isOptional ?? false
    guard binding.initializer != nil || isExplicitlyOptionalType else {
      throw MacroExpansionErrorMessage("@ContextEntry requires a default value.")
    }

    let peerStruct: StructDeclSyntax

    if let type = binding.typeAnnotation?.type.valueTypeName {
      peerStruct = try StructDeclSyntax(
        """
        private struct \(raw: keyTypeName): Key
        """
      ) {
        DeclSyntax("static let defaultValue: \(raw: type)= \(binding.initializer?.value ?? "nil")")
      }
    } else {
      peerStruct = try StructDeclSyntax(
        """
        private struct \(raw: keyTypeName): Key
        """
      ) {
        DeclSyntax("static let defaultValue = \(binding.initializer?.value ?? "nil")")
      }
    }
    return [DeclSyntax(peerStruct)]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard let variableDecl = declaration.as(VariableDeclSyntax.self),
      let binding = variableDecl.bindings.first,
      let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
    else {
      throw MacroExpansionErrorMessage("@ContextEntry can only be applied to a single variable.")
    }

    let name = identifierPattern.identifier.text
    let keyTypeName = "__Key_\(name)"

    let getAccessor: AccessorDeclSyntax =
      """
      get { self[\(raw: keyTypeName).self] }
      """

    if variableDecl.bindingSpecifier.tokenKind == .keyword(.var) {
      let setAccessor: AccessorDeclSyntax =
        """
        set { self[\(raw: keyTypeName).self] = newValue }
        """
      return [getAccessor, setAccessor]
    } else {
      throw MacroExpansionErrorMessage("@ContextEntry can only be applied to a 'var' declaration.")
    }
  }
}

extension TypeSyntax {
  fileprivate var valueTypeName: String {
    if self.description.contains("!") {
      self.description.dropLast() + "?"
    } else {
      self.description
    }
  }
}
