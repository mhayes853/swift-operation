import SwiftSyntax
import SwiftSyntaxMacros

public enum QueryRequestMacro: PeerMacro {
  private static let reservedArgumentNames = Set(["isolation", "context", "continuation", "path"])

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
    let pathSynthesizer = PathSyntesizerSyntax(node: node)
    let typeConformance = pathSynthesizer.operationTypeConformance.map { ", \($0)" } ?? ""
    return [
      """
      \(raw: syntax.accessorProperty)
      """,
      """
      \(raw: syntax.declaration.availability ?? "")
      \(raw: syntax.accessModifier)nonisolated struct \(raw: syntax.operationTypeNameDeclaration): \
      OperationCore.QueryRequest\(raw: typeConformance) {
        \(raw: syntax.operationTypeArgs)
        \(raw: pathSynthesizer.operationPathAccessor(with: syntax, in: context))
        \(raw: syntax.isPrivate ? "" : syntax.accessModifier)func fetch(
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
