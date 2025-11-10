// MARK: - Macro Declarations

/// A macro for declaring custom `OperationContext` properties.
///
/// This macro behaves similarly to SwiftUI's `@Entry` macro.
/// ```swift
/// extension OperationContext {
///   @ContextEntry var property = "default value"
/// }
/// ```
@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro ContextEntry() = #externalMacro(module: "OperationMacros", type: "ContextEntryMacro")

/// Defines and implements a conformance to the `OperationRequest` protocol.
///
/// ```swift
/// @OperationRequest
/// func myOperation() async throws -> Value {
///   // ...
/// }
/// ```
@attached(peer, names: overloaded, prefixed(`$`))
public macro OperationRequest() =
  #externalMacro(module: "OperationMacros", type: "OperationRequestMacro")

/// Defines and implements a conformance to the `QueryRequest` protocol.
///
/// ```swift
/// @QueryRequest
/// func myQuery() async throws -> Value {
///   // ...
/// }
/// ```
@attached(peer, names: overloaded, prefixed(`$`))
public macro QueryRequest(
  path: _OperationPathMacroSynthesizer = .inferredFromHashable
) = #externalMacro(module: "OperationMacros", type: "QueryRequestMacro")

/// Defines and implements a conformance to the `QueryRequest` protocol.
///
/// ```swift
/// @MutationRequest
/// func myMutation() async throws -> Value {
///   // ...
/// }
/// ```
@attached(peer, names: overloaded, prefixed(`$`))
public macro MutationRequest(
  path: _OperationPathMacroSynthesizer = .inferredFromHashable
) = #externalMacro(module: "OperationMacros", type: "MutationRequestMacro")

// MARK: - _OperationPathMacroSynthesizer

public struct _OperationPathMacroSynthesizer: Sendable {
  /// Synthesizes the `OperationPath` requirement of an operation to be the hashability of the
  /// operation type.
  ///
  /// Only use this if the arguments to your operation would syntesize a Hashable conformance.
  public static let inferredFromHashable = Self()
  
  /// Synthesizes the `OperationPath` requirement of an operation to be the identity of the
  /// operation type.
  ///
  /// Only use this if one of the arguments to your operation is named `id` with a type that
  /// conforms to Hashable.
  public static let inferredFromIdentifiable = Self()
  
  /// Synthesizes the `OperationPath` requirement of an operation to the result of a custom
  /// closure that you specify.
  ///
  /// The closure must account for all arguments passed to the operation.
  ///
  /// - Parameter construct: A closure to construct the `OperationPath`.
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
