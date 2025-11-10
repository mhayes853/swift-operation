import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - FunctionParameterSyntax

extension FunctionParameterSyntax {
  var operationalName: String {
    (self.secondName?.text ?? self.firstName.text).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

extension FunctionParameterSyntax {
  var isInout: Bool {
    guard let typeSyntax = self.type.as(AttributedTypeSyntax.self) else { return false }
    return typeSyntax.specifiers.contains {
      switch $0 {
      case .simpleTypeSpecifier(let simple): simple.specifier.tokenKind == .keyword(.inout)
      default: false
      }
    }
  }
}

extension FunctionParameterSyntax {
  var isIsolated: Bool {
    self.type.as(AttributedTypeSyntax.self)?.specifiers
      .contains(
        where: { specifier in
          switch specifier {
          case .simpleTypeSpecifier(let simple): simple.specifier.tokenKind == .keyword(.isolated)
          default: false
          }
        }
      ) ?? false
  }

  var isAnyActorIsolated: Bool {
    let attributed = self.type.as(AttributedTypeSyntax.self)
    guard let attributed, self.isIsolated else { return false }

    let base = attributed.baseType.strippedParens
    guard let optional = base.as(OptionalTypeSyntax.self) else { return false }

    let wrapped = optional.wrappedType.strippedParens
    guard let someOrAny = wrapped.as(SomeOrAnyTypeSyntax.self),
      someOrAny.someOrAnySpecifier.tokenKind == .keyword(.any)
    else {
      return false
    }

    if let ident = someOrAny.constraint.as(IdentifierTypeSyntax.self),
      ident.name.text == "Actor"
    {
      return true
    }

    return false
  }
}

extension TypeSyntax {
  fileprivate var strippedParens: TypeSyntax {
    var current = self
    while let tuple = current.as(TupleTypeSyntax.self),
      tuple.elements.count == 1,
      let only = tuple.elements.first
    {
      current = only.type
    }
    return current
  }
}

// MARK: - FunctionDeclSyntax

extension FunctionDeclSyntax {
  var accessModifier: String? {
    self.modifiers.first { modifier in
      switch modifier.name.tokenKind {
      case .keyword(.public),
        .keyword(.private),
        .keyword(.fileprivate),
        .keyword(.open),
        .keyword(.internal),
        .keyword(.package):
        true
      default: false
      }
    }?
    .name.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

extension FunctionDeclSyntax {
  var isStatic: Bool {
    self.modifiers.contains { modifier in
      switch modifier.name.tokenKind {
      case .keyword(.static): true
      default: false
      }
    }
  }
}

extension FunctionDeclSyntax {
  var availability: String? {
    guard let attrs = self.asProtocol(WithAttributesSyntax.self)?.attributes else {
      return nil
    }
    let syntaxes = attrs.compactMap { element -> String? in
      guard let attr = element.as(AttributeSyntax.self) else { return nil }
      if attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "available" {
        return attr.description.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      return nil
    }
    return syntaxes.isEmpty ? nil : syntaxes.joined(separator: "\n")
  }
}

extension FunctionDeclSyntax {
  var isAsync: Bool {
    self.signature.effectSpecifiers?.asyncSpecifier != nil
  }
}

extension FunctionDeclSyntax {
  var isThrowing: Bool {
    self.signature.effectSpecifiers?.throwsClause != nil
  }

  var errorTypeName: String? {
    guard
      let throwsClause = self.signature.effectSpecifiers?.throwsClause,
      let type = throwsClause.type
    else {
      return nil
    }
    if let ident = type.as(IdentifierTypeSyntax.self) {
      return ident.name.text
    }
    return type.description.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
