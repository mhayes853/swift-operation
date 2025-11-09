import SwiftSyntax

// MARK: - ClosureParamInfo

struct ClosureParamInfo: Hashable, Sendable {
  let name: String?
  let type: String?
}

// MARK: - ClosureExprSyntax

extension ClosureExprSyntax {
  var parameterInfo: [ClosureParamInfo] {
    guard
      let signature = self.signature,
      let parameterClause = signature.parameterClause
    else {
      return []
    }

    switch parameterClause {
    case .parameterClause(let clause):
      return clause.parameters.map { param in
        ClosureParamInfo(
          name: param.firstName.text,
          type: param.type?.as(IdentifierTypeSyntax.self)?.name.text
        )
      }
    default:
      return []
    }
  }
}
