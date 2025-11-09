@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro ContextEntry() = #externalMacro(module: "OperationMacros", type: "ContextEntryMacro")

@attached(peer, names: overloaded, prefixed(`$`), suffixed(`Operation`))
public macro OperationRequest() =
  #externalMacro(module: "OperationMacros", type: "OperationRequestMacro" )
