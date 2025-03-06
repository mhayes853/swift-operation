public protocol MutationProtocol: QueryProtocol {
}

extension MutationProtocol {
  public func _setup(context: inout QueryContext) {
    context.enableAutomaticFetchingCondition = .fetchManuallyCalled
  }
}
