import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct OperationMacrosPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = []
}
