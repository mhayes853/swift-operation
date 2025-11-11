import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public enum OperationRequestMacro: PeerMacro {
  private static let reservedArgumentNames = Set(["isolation", "context", "continuation"])

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let syntax = OperationFunctionSyntax(
      node: node,
      declaration: declaration,
      in: context,
      reservedNames: Self.reservedArgumentNames
    )
    guard let syntax else { return [] }

    return [
      """
      \(raw: syntax.accessorProperty())
      """,
      """
      \(raw: syntax.declaration.availability ?? "")
      \(raw: syntax.accessModifier)nonisolated struct \(raw: syntax.operationTypeNameDeclaration): \
      OperationCore.OperationRequest {
        \(raw: syntax.operationTypeArgs)
        \(raw: syntax.isPrivate ? "" : syntax.accessModifier)func run(
          isolation: isolated (any Actor)?,
          in context: OperationCore.OperationContext,
          with continuation: OperationCore.OperationContinuation<\(raw: syntax.returnTypeWithoutModifiers), \
      \(raw: syntax.errorType)>
        ) \(raw: syntax.operationTypeReturnSignature) {
          \(raw: syntax.functionFromOperationTypeInvoke)
        }
      }
      """
    ]
  }
}
