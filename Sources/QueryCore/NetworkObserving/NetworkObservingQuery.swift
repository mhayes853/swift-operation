extension QueryProtocol {
  public func refetchWhenNetworkStatus(
    changesTo status: NetworkStatus,
    using observer: some NetworkObserver
  ) -> some QueryProtocol<Value> {
    fatalError("TODO")
    return self
  }
}
