extension MutationRequest {
  /// The maximum length for ``MutationState/history``.
  ///
  /// Use this modifier to set a maximum length for your mutation's history. By default, this
  /// length of the history is unbounded, but you can use this modifier to limit the length to
  /// the n-most recent entries.
  ///
  /// The length must be greater than 0.
  ///
  /// - Parameter length: The maximum length of the history (must be greater than 0).
  /// - Returns: A ``ModifiedQuery``.
  public func maxHistory(
    length: Int
  ) -> ModifiedQuery<Self, _MaxHistoryLengthModifier<Self>> {
    precondition(length > 0, _tooSmallMutationHistoryLengthMessage(got: length))
    return self.modifier(_MaxHistoryLengthModifier(length: length))
  }
}

public struct _MaxHistoryLengthModifier<
  Query: MutationRequest
>: _ContextUpdatingQueryModifier {
  let length: Int

  public func setup(context: inout OperationContext) {
    context.mutationValues.maxHistoryLength = self.length
  }
}

package func _tooSmallMutationHistoryLengthMessage(got: Int) -> String {
  "History length must be greater than zero (Got: \(got))."
}
