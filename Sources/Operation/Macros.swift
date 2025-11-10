// MARK: - Macro Declarations

@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro ContextEntry() = #externalMacro(module: "OperationMacros", type: "ContextEntryMacro")

@attached(peer, names: overloaded, prefixed(`$`))
public macro OperationRequest() =
  #externalMacro(module: "OperationMacros", type: "OperationRequestMacro")

@attached(peer, names: overloaded, prefixed(`$`))
public macro QueryRequest(
  path: _OperationPathMacroSynthesizer = .inferredFromHashable
) = #externalMacro(module: "OperationMacros", type: "QueryRequestMacro")

@attached(peer, names: overloaded, prefixed(`$`))
public macro MutationRequest(
  path: _OperationPathMacroSynthesizer = .inferredFromHashable
) = #externalMacro(module: "OperationMacros", type: "MutationRequestMacro")

// MARK: - _OperationPathMacroSynthesizer

public struct _OperationPathMacroSynthesizer: Sendable {
  public static let inferredFromHashable = Self()
  public static let inferredFromIdentifiable = Self()

  public static func custom<each Argument>(
    construct: (repeat each Argument) -> OperationPath
  ) -> Self {
    Self()
  }

  private init() {}
}

// MARK: - _OperationHashableMetatype

public struct _OperationHashableMetatype<T>: Hashable, Sendable {
  public let type: T.Type

  public init(type: T.Type) {
    self.type = type
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.type == rhs.type
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self.type))
  }
}
