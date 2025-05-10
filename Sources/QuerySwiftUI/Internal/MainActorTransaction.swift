#if canImport(SwiftUI)
  import SwiftUI

  @MainActor
  struct MainActorTransaction {
    let transaction: Transaction?
  }

  @MainActor
  func withTransaction(_ transaction: MainActorTransaction, fn: () -> Void) {
    if let transaction = transaction.transaction {
      withTransaction(transaction) {
        fn()
      }
    } else {
      fn()
    }
  }
#endif
