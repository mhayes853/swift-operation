import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

enum PathSyntesizerSyntax {
  case inferredFromHashable
  case inferredFromIdentifiable

  var operationTypeConformance: String {
    switch self {
    case .inferredFromHashable: "Hashable"
    case .inferredFromIdentifiable: "Identifiable"
    }
  }

  init(node: AttributeSyntax) {
    switch node.arguments {
    case .argumentList(let args):
      guard let path = args.first(where: { $0.label?.text == "path" }) else {
        self = .inferredFromHashable
        return
      }
      switch path.expression.as(MemberAccessExprSyntax.self)?.declName.trimmedDescription {
      case "inferredFromIdentifiable":
        self = .inferredFromIdentifiable
      default:
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
    switch self {
    case .inferredFromHashable:
      return """
        \(function.accessModifier)var path: OperationCore.OperationPath {
          OperationCore.OperationPath(self)
        }
        """
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
      return """
        \(function.accessModifier)var path: OperationCore.OperationPath {
          OperationCore.OperationPath(id)
        }
        """
    }
  }
}
