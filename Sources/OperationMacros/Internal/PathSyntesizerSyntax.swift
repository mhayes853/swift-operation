import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - PathSyntesizerSyntax

enum PathSyntesizerSyntax {
  case inferredFromHashable
  case inferredFromIdentifiable
  case custom(ClosureExprSyntax)

  var operationTypeConformance: String? {
    switch self {
    case .inferredFromHashable: "Hashable, Sendable"
    case .inferredFromIdentifiable: "Identifiable"
    case .custom: nil
    }
  }

  var requiredTypeChecks: [OperationFunctionSyntax.CreateOperationInvokeTypeCheck] {
    var checks = [OperationFunctionSyntax.CreateOperationInvokeTypeCheck]()
    switch self {
    case .inferredFromHashable:
      checks.append(.hashable)
      checks.append(.sendable)
    case .inferredFromIdentifiable:
      checks.append(.idHashableSendable)
    case .custom:
      break
    }
    return checks
  }

  init(node: AttributeSyntax) {
    switch node.arguments {
    case .argumentList(let args):
      guard let path = args.first(where: { $0.label?.text == "path" }) else {
        self = .inferredFromHashable
        return
      }
      if path.expression.as(MemberAccessExprSyntax.self)?.declName.trimmedDescription
        == "inferredFromIdentifiable"
      {
        self = .inferredFromIdentifiable
      } else if let closure = path.expression.as(FunctionCallExprSyntax.self)?.trailingClosure {
        self = .custom(closure)
      } else {
        self = .inferredFromHashable
      }
    default:
      self = .inferredFromHashable
    }
  }

  func operationPathAccessor(
    with function: OperationFunctionSyntax,
    in context: some MacroExpansionContext
  ) -> String {
    let accessModifier = function.isPrivate ? "" : function.accessModifier
    switch self {
    case .inferredFromHashable:
      return ""  // NB: StatefulOperationRequest provides a default implementation.
    case .inferredFromIdentifiable:
      if !function.hasIDArgument {
        context.diagnose(
          Diagnostic(
            node: function.declaration,
            message: MacroExpansionErrorMessage(
              "An 'id' argument is required when using '.inferredFromIdentifiable'"
            )
          )
        )
      }
      return ""  // NB: StatefulOperationRequest provides a default implementation.
    case .custom(let syntax):
      if syntax.parameterInfo != function.pathClosureParamInfo {
        context.diagnose(
          Diagnostic(
            node: syntax,
            message: MacroExpansionErrorMessage(
              "Custom path closure must have arguments '\(function.expectedPathClosureArgs)'"
            )
          )
        )
      }
      return """
        \(accessModifier)var path: OperationCore.OperationPath {
          makePath(\(function.makePathInvoke))
        }
        private func makePath\(syntax.argsSignature)-> OperationCore.OperationPath {
          \(syntax.statements)
        }
        """
    }
  }
}

// MARK: - Helpers

extension ClosureExprSyntax {
  fileprivate var argsSignature: String {
    guard let params = self.signature?.parameterClause else { return "() " }
    return params.trimmedDescription
  }
}

extension OperationFunctionSyntax {
  fileprivate var makePathInvoke: String {
    self.functionArgs
      .compactMap { functionArg in
        let name = functionArg.operationalName
        guard !self.reservedNames.contains(name) else { return nil }
        return "\(name): \(name)"
      }
      .joined(separator: ", ")
  }

  fileprivate var expectedPathClosureArgs: String {
    let argsList = self.functionArgs
      .compactMap { functionArg in
        let name = functionArg.operationalName
        guard !self.reservedNames.contains(name) else { return nil }
        return "\(name): \(functionArg.type)"
      }
      .joined(separator: ", ")
    return "(\(argsList))"
  }

  fileprivate var pathClosureParamInfo: [ClosureParamInfo] {
    self.functionArgs
      .compactMap { functionArg in
        let name = functionArg.operationalName
        guard !self.reservedNames.contains(name) else { return nil }
        return ClosureParamInfo(
          name: name,
          type: functionArg.type.as(IdentifierTypeSyntax.self)?.name.text
        )
      }
  }
}
