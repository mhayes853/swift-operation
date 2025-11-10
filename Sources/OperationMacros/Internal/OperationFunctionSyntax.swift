import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - OperationFunctionSyntax

struct OperationFunctionSyntax {
  let declaration: FunctionDeclSyntax
  let parentTypeName: String?
  let selfArgName: String
  let baseOperationTypeName: String
  let reservedNames: Set<String>

  var accessModifier: String {
    self.declaration.accessModifier.map { "\($0) " } ?? ""
  }

  var isPrivate: Bool {
    self.declaration.accessModifier == "private"
  }

  var functionArgs: FunctionParameterListSyntax {
    self.declaration.signature.parameterClause.parameters
  }

  var hasNonReservedArgs: Bool {
    self.functionArgs.contains { !self.reservedNames.contains($0.operationalName) }
  }

  var hasIDArgument: Bool {
    self.functionArgs.contains { $0.operationalName == "id" }
  }

  var returnType: String {
    self.declaration.operationReturnTypeName
  }

  var returnTypeWithoutModifiers: String {
    self.declaration.operationReturnTypeNameWithoutModifiers
  }

  var errorType: String {
    self.declaration.operationErrorTypeName
  }

  var isVoid: Bool {
    self.returnType == "Void"
  }

  var hasGenericArgs: Bool {
    self.declaration.genericParameterClause != nil
  }

  var operationTypeReturnSignature: String {
    let returnTypeClause = self.isVoid ? "" : "-> \(self.returnType)"
    let throwsClause =
      if let typeName = self.declaration.errorTypeName {
        "throws(\(typeName))"
      } else if self.declaration.isThrowing {
        "throws"
      } else {
        ""
      }
    return "async \(throwsClause)\(returnTypeClause)"
  }

  var operationTypeArgs: String {
    var args = self.functionArgs
      .compactMap { functionArg -> String? in
        let name = functionArg.operationalName
        guard !self.reservedNames.contains(name) else { return nil }
        return "let \(name): \(functionArg.type)"
      }
    if let parentTypeName {
      if self.declaration.isStatic {
        args.append(
          "let \(self.selfArgName): Operation._OperationHashableMetatype<\(parentTypeName)>"
        )
      } else {
        args.append("let \(self.selfArgName): \(parentTypeName)")
      }
    }
    return args.joined(separator: "\n")
  }

  var createOperationTypeInvoke: String {
    var invoke = self.functionArgs
      .compactMap { functionArg -> String? in
        let name = functionArg.operationalName
        guard !self.reservedNames.contains(name) else { return nil }
        return "\(name): \(name)"
      }
    if self.parentTypeName != nil {
      invoke.append(
        "\(self.selfArgName): \(self.declaration.isStatic ? "Operation._OperationHashableMetatype(type: Self.self)" : "self")"
      )
    }
    return invoke.joined(separator: ", ")
  }

  var createOperationTypeFunctionArgs: String {
    self.declaration.signature.parameterClause.parameters
      .compactMap { functionArg in
        let name = functionArg.secondName ?? functionArg.firstName
        guard !self.reservedNames.contains(name.text) else { return nil }
        return functionArg.description.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      .joined()
  }

  var functionFromOperationTypeInvoke: String {
    let args = self.functionArgs.map { functionArg in
      let value =
        self.reservedNames.contains(functionArg.operationalName)
        ? functionArg.operationalName : "self.\(functionArg.operationalName)"
      return
        "\(functionArg.firstName.text.trimmingCharacters(in: .whitespacesAndNewlines)): \(value)"
    }
    return """
      \(self.declaration.isThrowing ? "try " : "")\(self.declaration.isAsync ? "await " : "")\
      \(self.parentTypeName != nil ? "\(self.selfArgName).\(self.declaration.isStatic ? "type." : "")" : "")\
      \(self.declaration.name)(\(args.joined(separator: ", ")))
      """
  }

  var accessorProperty: String {
    let isFunction = self.hasNonReservedArgs || self.hasGenericArgs
    return """
      \(self.declaration.availability ?? "")
      \(self.accessModifier)\
      \(self.declaration.isStatic ? "static " : "")nonisolated \(isFunction ? "func" : "var") \
      $\(self.declaration.name)\
      \(self.declaration.genericParameterClause ?? "")\
      \(isFunction ? "(\(self.createOperationTypeFunctionArgs)) ->" : ":") \
      \(self.operationTypeName) {
        \(self.operationTypeName)(\(self.createOperationTypeInvoke))
      }
      """
  }

  var operationTypeNameDeclaration: String {
    self.baseOperationTypeName
      + "\(self.declaration.genericParameterClause ?? "")"
  }

  var operationTypeName: String {
    let genericsList = self.declaration.genericParameterClause?.parameters
      .map { $0.name.text }
      .joined(separator: ", ")
    return self.baseOperationTypeName + (genericsList.map { "<\($0)>" } ?? "")
  }
}

extension OperationFunctionSyntax {
  init?(
    node: AttributeSyntax,
    declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext,
    reservedNames: Set<String> = []
  ) {
    guard let declaration = declaration.as(FunctionDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(
          node: declaration,
          message: MacroExpansionErrorMessage("@OperationRequest can only be applied to functions.")
        )
      )
      return nil
    }
    for functionArg in declaration.signature.parameterClause.parameters {
      if functionArg.ellipsis != nil {
        context.diagnose(
          Diagnostic(
            node: functionArg,
            message: MacroExpansionErrorMessage("Variadic arguments are not supported.")
          )
        )
      }
      if functionArg.isInout {
        context.diagnose(
          Diagnostic(
            node: functionArg,
            message: MacroExpansionErrorMessage("Inout arguments are not supported.")
          )
        )
      }

      if functionArg.operationalName == "isolation" && !functionArg.isAnyActorIsolated {
        context.diagnose(
          Diagnostic(
            node: functionArg,
            message: MacroExpansionErrorMessage(
              "'isolation' argument must be 'isolated (any Actor)?'."
            )
          )
        )
      }

      if functionArg.operationalName == "context" {
        guard let typeName = functionArg.type.as(IdentifierTypeSyntax.self) else { continue }
        if typeName.name.text != "OperationContext" {
          context.diagnose(
            Diagnostic(
              node: functionArg,
              message: MacroExpansionErrorMessage(
                "'context' argument must be of type 'OperationContext'."
              )
            )
          )
        }
      }

      if functionArg.operationalName == "continuation" {
        guard let typeName = functionArg.type.as(IdentifierTypeSyntax.self) else { continue }
        let returnType = declaration.operationReturnTypeNameWithoutModifiers
        let errorType = declaration.operationErrorTypeName

        if typeName.name.text != "OperationContinuation" {
          context.diagnose(
            Diagnostic(
              node: functionArg,
              message: MacroExpansionErrorMessage(
                "'continuation' argument must be of type 'OperationContinuation<\(returnType), \(errorType)>'"
              )
            )
          )
        }
      }

      if functionArg.operationalName == "path" && reservedNames.contains("path") {
        guard let typeName = functionArg.type.as(IdentifierTypeSyntax.self) else { continue }
        if typeName.name.text != "OperationPath" {
          context.diagnose(
            Diagnostic(
              node: functionArg,
              message: MacroExpansionErrorMessage("'path' argument must be of type 'OperationPath'")
            )
          )
        }
      }
    }

    self.init(
      declaration: declaration,
      parentTypeName: context.parentTypeName,
      selfArgName: String(context.makeUniqueName("type").text.drop { $0 == "$" }),
      baseOperationTypeName: context.makeUniqueName(declaration.name.text).text,
      reservedNames: reservedNames
    )
  }
}

// MARK: - Helpers

extension FunctionDeclSyntax {
  fileprivate var operationReturnTypeName: String {
    self.signature.returnClause?.type.trimmedDescription ?? "Void"
  }

  fileprivate var operationReturnTypeNameWithoutModifiers: String {
    if let attributed = self.signature.returnClause?.type.as(AttributedTypeSyntax.self) {
      return attributed.baseType.trimmedDescription
    }
    return self.operationReturnTypeName
  }

  fileprivate var operationErrorTypeName: String {
    if let errorTypeName = self.errorTypeName {
      errorTypeName
    } else if self.isThrowing {
      "any Error"
    } else {
      "Never"
    }
  }
}
