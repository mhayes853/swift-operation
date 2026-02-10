import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public enum RunMacro: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    let arguments = Array(node.arguments)

    let operation = arguments[0].expression.trimmedDescription
    let initialContext =
      arguments.count >= 2
      ? arguments[1].expression.trimmedDescription
      : "OperationCore.OperationContext()"
    let continuation =
      arguments.count >= 3
      ? arguments[2].expression.trimmedDescription
      : "OperationCore.OperationContinuation { _, _ in }"

    return """
      OperationCore.OperationRunner(
        operation: \(raw: operation),
        initialContext: \(raw: initialContext)
      ).run(with: \(raw: continuation))
      """
  }

  private static func invalidExpansion() -> ExprSyntax {
    "fatalError(\"Invalid #run macro invocation\")"
  }
}
