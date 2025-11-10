import SwiftSyntax
import SwiftSyntaxMacros

public enum MutationRequestMacro: PeerMacro {
  private static let reservedArgumentNames = Set([
    "isolation", "context", "continuation", "arguments", "path"
  ])

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

    let argumentsTypeName =
      syntax.functionArgs
      .first { $0.operationalName == "arguments" }?
      .type
      .typeNameWithoutModifiers
      ?? "Void"

    return [
      """
      \(raw: syntax.accessorProperty)
      """,
      """
      \(raw: syntax.declaration.availability ?? "")
      \(raw: syntax.accessModifier)nonisolated struct \(raw: syntax.operationTypeNameDeclaration): \
      OperationCore.MutationRequest\(raw: typeConformance) {
        \(raw: syntax.isPrivate ? "" : syntax.accessModifier)typealias Arguments = \(raw: argumentsTypeName)
        \(raw: syntax.operationTypeArgs)
        \(raw: pathSynthesizer.operationPathAccessor(with: syntax, in: context))
        \(raw: syntax.isPrivate ? "" : syntax.accessModifier)func mutate(
          isolation: isolated (any Actor)?,
          with arguments: Arguments,
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
