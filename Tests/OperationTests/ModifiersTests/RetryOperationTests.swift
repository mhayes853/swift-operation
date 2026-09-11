import CustomDump
import Operation
import OperationTestHelpers
import Testing

@Suite("RetryOperation tests")
struct RetryOperationTests {
  @Test("Zero Retries, Does Not Perform Any Retries")
  func zeroRetriesDoesNotPerformAnyRetries() async {
    let query = FailingQuery()
      .backoff(.noBackoff)
      .delayer(.noDelay)
      .retry(limit: 0)
      .defaultValue("blob")
    let store = OperationStore.detached(query: query)
    await #expect(throws: FailingQuery.SomeError.self) {
      try await store.fetch()
    }
  }

  @Test("Fetch Errors, Then Retries The Specified Number Of Times")
  func fetchErrorsThenRetriesTheSpecifiedNumberOfTimes() async {
    let query = CountingQuery()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 3),
      initialValue: nil
    )
    await query.ensureFails()

    await #expect(throws: CountingQuery.SomeError.self) {
      try await store.fetch()
    }
    let count = await query.fetchCount
    expectNoDifference(count, 4)
  }

  @Test("Succeeds On Second Refetch, Returns Value")
  func succeedsOnSecondRefetchReturnsValue() async throws {
    let query = SucceedOnNthRefetchQuery(index: 2)
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 3),
      initialValue: nil
    )
    let value = try await store.fetch()
    expectNoDifference(value, SucceedOnNthRefetchQuery.value)
  }

  @Test("Succeeds On Final Refetch, Returns Value")
  func succeedsOnFinalRefetchReturnsValue() async throws {
    let query = SucceedOnNthRefetchQuery(index: 2)
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 3),
      initialValue: nil
    )
    let value = try await store.fetch()
    expectNoDifference(value, SucceedOnNthRefetchQuery.value)
  }

  @Test("Does Not Retry Every Page Fetch When Fetching All Pages")
  func doesNotRetryEveryPageFetchWhenFetchingAllPages() async throws {
    let query = FlakeyPaginated()
    query.values.withLock { $0.failOnPageId = -1 }
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 3)
    )
    try await store.fetchNextPage()
    try await store.fetchNextPage()
    try await store.fetchNextPage()

    query.values.withLock {
      $0.failOnPageId = 2
      $0.fetchCount = 0
    }
    _ = try? await store.refetchAllPages()
    query.values.withLock {
      expectNoDifference(
        $0.fetchCount,
        6,
        "The fetch count should account for fetching the first 2 pages successfully, and then retrying just the third page 3 times after the initial attempt."
      )
    }
  }

  @Test("Max Retries Is Based Off Of Limit")
  func maxRetriesIsBasedOffOfLimit() async throws {
    let query = FailingQuery().backoff(.noBackoff)
      .delayer(.noDelay)
      .retry(limit: 10)
    let store = OperationStore.detached(query: query, initialValue: nil)
    expectNoDifference(store.context.operationMaxRetries, 10)
  }

  @Test("Uses Context Max Retries Over Query Limit")
  func usesContextMaxRetriesOverQueryLimit() async throws {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 3),
      initialValue: nil
    )
    store.context.operationMaxRetries = 10
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 11)
  }

  @Test("Delays Between Retries Using The Specified Backoff Function")
  func delaysBetweenRetries() async throws {
    let delayer = TestDelayer()
    let query = FailingQuery()
      .delayer(delayer)
      .backoff(.linear(.milliseconds(1000)))
      .retry(limit: 5)
    let store = OperationStore.detached(query: query, initialValue: nil)
    _ = try? await store.fetch()
    expectNoDifference(
      delayer.delays,
      [
        .milliseconds(1000), .milliseconds(2000), .milliseconds(3000), .milliseconds(4000),
        .milliseconds(5000)
      ]
    )
  }

  @Test("Does Not Cancel If Operation Is Not Cancellable")
  func doesNotCancelIfOperationIsNotCancellable() async throws {
    let query = TestQuery()
      .delayer(.noDelay)
      .backoff(.linear(.milliseconds(1000)))
      .retry(limit: 5)
    let store = OperationStore.detached(query: query, initialValue: nil)
    let task = store.fetchTask()
    task.cancel()

    await #expect(throws: Never.self) {
      try await task.runIfNeeded()
    }
  }

  @Test("Has Nil Retry Index On First Fetch Attempt")
  func hasNilRetryIndexOnFirstFetchAttempt() async {
    let query = RetryIndexReadingQuery()
    let store = OperationStore.detached(query: query.retry(limit: 10), initialValue: nil)
    _ = await store.fetch()
    let index = await query.retryIndex
    expectNoDifference(index, nil)
  }

  @Test("Has Nil Retry Index On First Fetch Attempt When Retry Limit Is 0")
  func hasNilRetryIndexOnFirstFetchAttemptWhenRetryLimitIs0() async {
    let query = RetryIndexReadingQuery()
    let store = OperationStore.detached(query: query.retry(limit: 0), initialValue: nil)
    _ = await store.fetch()
    let index = await query.retryIndex
    expectNoDifference(index, nil)
  }

  @Test("All Retry Indicies")
  func allRetryIndicies() async {
    let query = RetryIndiciesReadingQuery()
    let store = OperationStore.detached(
      query: query.retry(limit: 5).backoff(.noBackoff).delayer(.noDelay),
      initialValue: nil
    )
    _ = try? await store.fetch()
    let indicies = await query.retryIndicies
    expectNoDifference(indicies, [nil, 0, 1, 2, 3, 4])
  }

  @Test("Only Applies First Application Of Retry Modifier")
  func onlyAppliesFirstApplicationOfRetryModifier() async {
    let query = RetryIndiciesReadingQuery()
    let store = OperationStore.detached(
      query: query.retry(limit: 5)
        .retry(limit: 3)
        .backoff(.noBackoff)
        .delayer(.noDelay),
      initialValue: nil
    )
    expectNoDifference(store.context.operationMaxRetries, 5)
    _ = try? await store.fetch()
    let indicies = await query.retryIndicies
    expectNoDifference(indicies, [nil, 0, 1, 2, 3, 4])
  }

  @Test("Predicate Returning False Stops Retrying Before The Limit Is Reached")
  func predicateReturningFalseStopsRetryingBeforeTheLimitIsReached() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 5) { _, context in (context.operationRetryIndex ?? -1) < 1 },
      initialValue: nil
    )
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 3)
  }

  @Test("Does Not Delay When The Predicate Declines A Retry")
  func doesNotDelayWhenThePredicateDeclinesARetry() async {
    let delayer = TestDelayer()
    let query = FailingQuery()
      .delayer(delayer)
      .backoff(.linear(.milliseconds(1000)))
      .retry(limit: 5) { _, _ in false }
    let store = OperationStore.detached(query: query, initialValue: nil)
    _ = try? await store.fetch()
    expectNoDifference(
      delayer.delays,
      [],
      "The backoff should not be awaited for an error that does not warrant a retry."
    )
  }

  @Test("Passes The Thrown Error To The Predicate")
  func passesTheThrownErrorToThePredicate() async {
    let errors = ErrorRecorder()
    let query = FailingQuery()
      .backoff(.noBackoff)
      .delayer(.noDelay)
      .retry(limit: 2) { error, _ in
        await errors.record(error)
        return true
      }
    let store = OperationStore.detached(query: query, initialValue: nil)
    _ = try? await store.fetch()
    let recorded = await errors.errors
    expectNoDifference(recorded.count, 2)
    expectNoDifference(recorded.allSatisfy { $0 is FailingQuery.SomeError }, true)
  }

  @Test("Awaits The Predicate Once Per Failed Attempt That Is Not The Last")
  func awaitsThePredicateOncePerFailedAttemptThatIsNotTheLast() async {
    let counter = Counter()
    let query = FailingQuery()
      .backoff(.noBackoff)
      .delayer(.noDelay)
      .retry(limit: 3) { _, _ in
        await counter.increment()
        return true
      }
    let store = OperationStore.detached(query: query, initialValue: nil)
    _ = try? await store.fetch()
    let count = await counter.count
    expectNoDifference(
      count,
      3,
      "The predicate should not be evaluated on the final attempt, since the limit already rules out a retry."
    )
  }

  @Test("Bare Predicate Modifier Retries Without An Upper Bound")
  func barePredicateModifierRetriesWithoutAnUpperBound() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(when: { _, context in (context.operationRetryIndex ?? -1) < 8 }),
      initialValue: nil
    )
    expectNoDifference(store.context.operationMaxRetries, Int.max)
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 10)
  }

  @Test("Is Not A Known Last Run Attempt When The Retry Condition Is Unbounded")
  func isNotAKnownLastRunAttemptWhenTheRetryConditionIsUnbounded() async {
    let query = LastRunAttemptReadingQuery()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(when: { _, context in (context.operationRetryIndex ?? -1) < 2 }),
      initialValue: nil
    )
    _ = try? await store.fetch()
    let flags = await query.flags
    expectNoDifference(flags, [false, false, false, false])
  }

  @Test("Is A Known Last Run Attempt On The Final Attempt Of A Bounded Condition")
  func isAKnownLastRunAttemptOnTheFinalAttemptOfABoundedCondition() async {
    let query = LastRunAttemptReadingQuery()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff).delayer(.noDelay).retry(limit: 3),
      initialValue: nil
    )
    _ = try? await store.fetch()
    let flags = await query.flags
    expectNoDifference(flags, [false, false, false, true])
  }

  @Test("Combining Conditions Uses The Smaller Retry Bound")
  func combiningConditionsUsesTheSmallerRetryBound() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(.maxRetries(10) && .maxRetries(3)),
      initialValue: nil
    )
    expectNoDifference(store.context.operationMaxRetries, 3)
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 4)
  }

  @Test("Combining An Unbounded Condition With A Bounded One Keeps The Bound")
  func combiningAnUnboundedConditionWithABoundedOneKeepsTheBound() async {
    let query = FailingQuery()
      .backoff(.noBackoff)
      .delayer(.noDelay)
      .retry(.maxRetries(4) && OperationRetryCondition { _, _ in true })
    let store = OperationStore.detached(query: query, initialValue: nil)
    expectNoDifference(store.context.operationMaxRetries, 4)
  }

  @Test("Never Condition Does Not Perform Any Retries")
  func neverConditionDoesNotPerformAnyRetries() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff).delayer(.noDelay).retry(.never),
      initialValue: nil
    )
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }

  @Test("Stops Retrying When The Underlying Task Is Cancelled")
  func stopsRetryingWhenTheUnderlyingTaskIsCancelled() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff).delayer(.noDelay).retry(limit: 5),
      initialValue: nil
    )
    let task = store.fetchTask()
    task.cancel()
    _ = try? await task.runIfNeeded()
    let count = await query.fetchCount
    expectNoDifference(
      count,
      1,
      "A cancelled task should not burn through every remaining retry attempt."
    )
  }

  @Test("Combining Conditions With Or Uses The Larger Retry Bound")
  func combiningConditionsWithOrUsesTheLargerRetryBound() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(.maxRetries(2) || .maxRetries(5)),
      initialValue: nil
    )
    expectNoDifference(store.context.operationRetryCondition.maxRetries, 5)
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 6)
  }

  @Test("Or Combines The Predicates Of Both Operands")
  func orCombinesThePredicatesOfBothOperands() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(
          .maxRetries(5)
            && (OperationRetryCondition { _, context in (context.operationRetryIndex ?? -1) < 0 }
              || OperationRetryCondition { _, context in (context.operationRetryIndex ?? -1) < 2 })
        ),
      initialValue: nil
    )
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(
      count,
      4,
      "Retries should continue for as long as either predicate permits one, up to the bound."
    )
  }

  @Test("Or Does Not Evaluate The Right Hand Predicate When The Left One Permits A Retry")
  func orDoesNotEvaluateTheRightHandPredicateWhenTheLeftOnePermitsARetry() async {
    let counter = Counter()
    let query = FailingQuery()
      .backoff(.noBackoff)
      .delayer(.noDelay)
      .retry(
        .maxRetries(3)
          && (OperationRetryCondition { _, _ in true }
            || OperationRetryCondition { _, _ in
              await counter.increment()
              return true
            })
      )
    let store = OperationStore.detached(query: query, initialValue: nil)
    _ = try? await store.fetch()
    let count = await counter.count
    expectNoDifference(count, 0)
  }

  @Test("Or With A Max Retries Operand Keeps The Other Operand's Predicate")
  func orWithAMaxRetriesOperandKeepsTheOtherOperandsPredicate() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(.maxRetries(3) && (.maxRetries(1) || OperationRetryCondition { _, _ in false })),
      initialValue: nil
    )
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(
      count,
      1,
      "`maxRetries` has no predicate, so using it as an `||` operand only affects the bound."
    )
  }

  @Test("And With A Max Retries Operand Keeps The Other Operand's Predicate")
  func andWithAMaxRetriesOperandKeepsTheOtherOperandsPredicate() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(
          .maxRetries(5)
            && OperationRetryCondition { _, context in (context.operationRetryIndex ?? -1) < 1 }
        ),
      initialValue: nil
    )
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 3)
  }

  @Test("Or With Never Falls Back To The Other Operand")
  func orWithNeverFallsBackToTheOtherOperand() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(.never || .maxRetries(3)),
      initialValue: nil
    )
    expectNoDifference(store.context.operationRetryCondition.maxRetries, 3)
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 4)
  }

  @Test("Exposes The Retry Bound Of A Condition")
  func exposesTheRetryBoundOfACondition() {
    expectNoDifference(OperationRetryCondition.maxRetries(4).maxRetries, 4)
    expectNoDifference(OperationRetryCondition.never.maxRetries, 0)
    expectNoDifference(OperationRetryCondition { _, _ in true }.maxRetries, nil)
    expectNoDifference((OperationRetryCondition.maxRetries(4) && .maxRetries(9)).maxRetries, 4)
    expectNoDifference((OperationRetryCondition.maxRetries(4) || .maxRetries(9)).maxRetries, 9)
  }

  // MARK: - Merge

  @Test("Overrides The Condition Of The Retry Modifiers Applied Around It By Default")
  func overridesTheConditionOfTheRetryModifiersAppliedAroundItByDefault() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 1)
        .retry(limit: 3) { _, _ in false },
      initialValue: nil
    )
    expectNoDifference(store.context.operationMaxRetries, 1)
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 2)
  }

  @Test("Or Merge Combines With The Condition Of The Retry Modifiers Applied Around It")
  func orMergeCombinesWithTheConditionOfTheRetryModifiersAppliedAroundIt() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 1, merging: .or)
        .retry(limit: 3),
      initialValue: nil
    )
    expectNoDifference(store.context.operationMaxRetries, 3)
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 4)
  }

  @Test("And Merge Narrows The Condition Of The Retry Modifiers Applied Around It")
  func andMergeNarrowsTheConditionOfTheRetryModifiersAppliedAroundIt() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(merging: .and) { _, context in (context.operationRetryIndex ?? -1) < 1 }
        .retry(limit: 5),
      initialValue: nil
    )
    expectNoDifference(store.context.operationMaxRetries, 5)
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 3)
  }

  @Test("And Merge Permits No Retries Without A Retry Modifier Applied Around It")
  func andMergePermitsNoRetriesWithoutARetryModifierAppliedAroundIt() async {
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 5, merging: .and),
      initialValue: nil
    )
    expectNoDifference(store.context.operationMaxRetries, 0)
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 1)
  }

  @Test("Custom Merge Receives The Modifier's Condition And The Existing One")
  func customMergeReceivesTheModifiersConditionAndTheExistingOne() async {
    let merge = OperationRetryCondition.Merge { condition, existing in
      var merged = condition
      merged.maxRetries = (condition.maxRetries ?? 0) + (existing.maxRetries ?? 0)
      return merged
    }
    let query = CountingQuery()
    await query.ensureFails()
    let store = OperationStore.detached(
      query: query.backoff(.noBackoff)
        .delayer(.noDelay)
        .retry(limit: 1, merging: merge)
        .retry(limit: 2),
      initialValue: nil
    )
    expectNoDifference(store.context.operationMaxRetries, 3)
    _ = try? await store.fetch()
    let count = await query.fetchCount
    expectNoDifference(count, 4)
  }

  @Test("Retries An Operation Run With The Context Of A Retrying Operation")
  func retriesAnOperationRunWithTheContextOfARetryingOperation() async {
    let counter = Counter()
    await #expect(throws: FailingQuery.SomeError.self) {
      try await #run(
        $nestedRetryingOperation(counter: counter)
          .retry(limit: 1)
          .backoff(.noBackoff)
          .delayer(.noDelay)
      )
    }
    let count = await counter.count
    expectNoDifference(count, 6, "The nested operation should retry twice on each of 2 attempts.")
  }
}

@OperationRequest
private func nestedRetryingOperation(
  counter: Counter,
  context: OperationContext
) async throws -> Int {
  try await #run(
    $countingFailingOperation(counter: counter)
      .retry(limit: 2)
      .backoff(.noBackoff)
      .delayer(.noDelay),
    context: context
  )
}

@OperationRequest
private func countingFailingOperation(counter: Counter) async throws -> Int {
  await counter.increment()
  throw FailingQuery.SomeError()
}

private actor Counter {
  private(set) var count = 0

  func increment() {
    self.count += 1
  }
}

private actor ErrorRecorder {
  private(set) var errors = [any Error]()

  func record(_ error: any Error) {
    self.errors.append(error)
  }
}

private actor LastRunAttemptReadingQuery: QueryRequest, Identifiable {
  private(set) var flags = [Bool]()

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, any Error>
  ) async throws -> Int {
    await isolate(self) { @Sendable in $0.flags.append(context.isKnownLastRunAttempt) }
    throw SomeError()
  }

  private struct SomeError: Error {}
}

private actor RetryIndexReadingQuery: QueryRequest, Identifiable {
  private(set) var retryIndex: Int?

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, Never>
  ) async -> Int {
    await isolate(self) { @Sendable in $0.retryIndex = context.operationRetryIndex }
    return 0
  }
}

private actor RetryIndiciesReadingQuery: QueryRequest, Identifiable {
  private(set) var retryIndicies = [Int?]()

  func fetch(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Int, any Error>
  ) async throws -> Int {
    await isolate(self) { @Sendable in $0.retryIndicies.append(context.operationRetryIndex) }
    throw SomeError()
  }

  private struct SomeError: Error {}
}
