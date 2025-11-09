import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct OperationMacrosPlugin: CompilerPlugin {
  let providingMacros: [any Macro.Type] = [
    ContextEntryMacro.self,
    OperationRequestMacro.self,
    QueryRequestMacro.self
  ]
}
