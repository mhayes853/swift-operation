// MARK: - MutationProtocol

public protocol MutationProtocol<Arguments>: QueryProtocol
where StateValue == Value?, State == MutationState<Value> {
  associatedtype Arguments: Sendable

  func mutate(with arguments: Arguments, in context: QueryContext) async throws -> Value

}

extension MutationProtocol {
  public func _setup(context: inout QueryContext) {
    context.enableAutomaticFetchingCondition = .fetchManuallyCalled
  }

  public func fetch(in context: QueryContext) async throws -> Value {
    fatalError("TODO")
  }
}
