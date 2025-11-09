@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro ContextEntry() = #externalMacro(module: "OperationMacros", type: "ContextEntryMacro")
