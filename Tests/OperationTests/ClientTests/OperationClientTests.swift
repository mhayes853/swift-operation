import CustomDump
import IssueReporting
@_spi(Warnings) import Operation
@_spi(Warnings) import OperationTestHelpers
import Testing

@Suite("OperationClient tests")
struct OperationClientTests {
  @Test("Maintains The Same Query State For Multiple Stores With The Same Query")
  func maintainsValueForMultipleStores() async throws {
    let client = OperationClient()
    let store1 = client.store(for: TestQuery())
    try await store1.fetch()
    let store2 = client.store(for: TestQuery())

    expectNoDifference(store1.currentValue, store2.currentValue)
    expectNoDifference(store2.currentValue, TestQuery.value)
  }

  @Test("Returns Same Store Reference For Same Query")
  func returnsSameStoreReferenceForSameQuery() async throws {
    let client = OperationClient()
    let store1 = client.store(for: TestQuery())
    let store2 = client.store(for: TestQuery())

    expectNoDifference(store1 === store2, true)
  }

  @Test("Reports Issue When Different Query Type Has The Same Path As Another Query")
  func cannotHaveDuplicatePaths() async throws {
    let client = OperationClient()
    _ = client.store(for: TestQuery())
    withKnownIssue {
      _ = client.store(for: TestQuery().defaultValue(TestQuery.value + 10))
    } matching: {
      $0.comments.contains(
        .warning(
          .duplicatePath(expectedType: TestQuery.self, foundType: TestQuery.Default.self)
        )
      )
    }
  }

  @Test("Does Not Crash When Duplicate Query Paths")
  func duplicatePathsCrashPrevention() async throws {
    let client = OperationClient()
    _ = client.store(for: TestQuery())
    withExpectedIssue {
      let store = client.store(for: TestQuery().defaultValue(TestQuery.value + 10))
      _ = store.currentValue
    }
  }

  @Test("Does Not Share States Between Different Queries")
  func doesNotShareStateBetweenDifferentQueries() async throws {
    let client = OperationClient()
    let store1 = client.store(for: TestQuery())
    try await store1.fetch()
    let store2 = client.store(for: TestStringQuery().defaultValue("bar"))

    expectNoDifference(store1.currentValue, TestQuery.value)
    expectNoDifference(store2.currentValue, "bar")
  }

  @Test("Loads Queries Matching Path Prefix")
  func matchesPathPrefix() async throws {
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2])
    let q2 = PathableQuery(value: 2, path: ["blob", "tlob"])
    let q3 = PathableQuery(value: 3, path: [1, "blobby"])
    _ = client.store(for: q1)
    let store1 = client.store(for: q2)
    let store2 = client.store(for: q3)
    _ = try await (store1.fetch(), store2.fetch())

    let stores = client.stores(matching: [1])
    try #require(stores.count == 2)

    expectNoDifference(stores[q1.path]?.currentValue as? Int, nil)
    expectNoDifference(stores[q3.path]?.currentValue as? Int, 3)

    try await stores[q1.path]?.run()
    expectNoDifference(stores[q1.path]?.currentValue as? Int, 1)
  }

  @Test("Clears Queries That Match The Specified Path")
  func clearQueriesMatchingPath() async throws {
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let q2 = PathableQuery(value: 2, path: [1, 3]).defaultValue(20)
    let q3 = PathableQuery(value: 3, path: [2, 4]).defaultValue(30)
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)

    client.clearStores(matching: [1])

    let stores = client.stores(matching: [])
    expectNoDifference(stores.count, 1)
    expectNoDifference(stores[q3.path] != nil, true)
  }

  @Test("Clears Queries That Equal The Specified Path")
  func clearQueryWithPath() {
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let q2 = PathableQuery(value: 2, path: [1, 3]).defaultValue(20)
    let q3 = PathableQuery(value: 3, path: [2, 4]).defaultValue(30)
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)

    client.clearStore(with: [1, 2])

    let stores = client.stores(matching: [])
    expectNoDifference(stores.count, 2)
    expectNoDifference(stores[q3.path] != nil, true)
    expectNoDifference(stores[q2.path] != nil, true)
    expectNoDifference(stores[q1.path] == nil, true)
  }

  @Test("Only Retrieves Stores Of Specified State Type When Pattern Matching")
  func onlyRetrievesStoresOfSpecifiedStateTypeWhenPatternMatching() {
    let client = OperationClient()
    let q1 = TaggedPathableQuery<Int>(value: 1, path: [1, 2])
    let q2 = TaggedPathableQuery<Int>(value: 2, path: [2, 3])
    let q3 = TaggedPathableQuery<String>(value: "foo", path: [1, 4])
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)

    let stores = client.stores(matching: [1], of: TaggedPathableQuery<Int>.State.self)
    expectNoDifference(stores.count, 1)
    expectNoDifference(stores[q1.path] != nil, true)
    expectNoDifference(stores[q2.path] == nil, true)
    expectNoDifference(stores[q3.path] == nil, true)
  }

  @Test("Sets Value For Store Through Path")
  func setValueForStoreThroughPath() async throws {
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let store = client.store(for: q1)
    let opaqueStore = try #require(client.stores(matching: []).first)

    opaqueStore.uncheckedSetCurrentValue(20)
    expectNoDifference(store.currentValue, 20)
  }

  @Test("Sets Result For Store Through Path")
  func setResultForStoreThroughPath() async throws {
    struct SomeError: Equatable, Error {}

    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let store = client.store(for: q1)
    let opaqueStore = try #require(client.stores(matching: []).first)

    opaqueStore.uncheckedSetResult(to: .success(20))
    expectNoDifference(store.currentValue, 20)

    opaqueStore.uncheckedSetResult(to: .failure(SomeError()))
    expectNoDifference(store.error as? SomeError, SomeError())
  }

  @Test("Uses Default Value For AnyOperationStore")
  func defaultAnyOperationStoreValue() async throws {
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    _ = client.store(for: q1)

    let stores = client.stores(matching: [])
    try #require(stores.count == 1)

    expectNoDifference(stores[q1.path]?.currentValue as? Int, 10)
    expectNoDifference(stores[q1.path]?.initialValue as? Int, 10)
  }

  @Test("Adds Current OperationClient Instance To The OperationContext")
  func operationClientInContext() async throws {
    let client = OperationClient()
    let query = ContextReadingQuery()
    let store = client.store(for: query)
    try await store.fetch()

    let context = await query.latestContext
    let contextClient = try #require(context?.operationClient)
    expectNoDifference(client === contextClient, true)
  }

  @Test("Sets Custom OperationClient Instance To The OperationContext")
  func setCustomOperationClientInContext() async throws {
    let client = OperationClient()
    let query = ContextReadingQuery()
    let store = OperationStore.detached(query: query, initialValue: nil)
    store.context.operationClient = client
    try await store.fetch()

    let context = await query.latestContext
    let contextClient = try #require(context?.operationClient)
    expectNoDifference(client === contextClient, true)
  }

  @Test("Loads AnyStore In A Loading State")
  func loadAnyStoreInLoadingState() async throws {
    let client = OperationClient()
    let query = SleepingQuery()
    let store = client.store(for: query)
    query.didBeginSleeping = {
      let anyStore = client.store(with: query.path)
      expectNoDifference(anyStore?.isLoading, true)
      query.resume()
    }
    try await store.fetch()
  }

  @Test("No AnyStore For OperationPath That Does Not Exist")
  func noAnyStoreForOperationPathThatDoesNotExist() async throws {
    let client = OperationClient()
    let store = client.store(with: [1, 2, 3])
    expectNoDifference(store == nil, true)
  }

  @Test("Only Subscribes To OperationController Once Per Store")
  func onlySubscribesToOperationControllerOncePerStore() async throws {
    let client = OperationClient()
    let controller = CountingController<TestQuery.State>()
    let query = TestQuery().controlled(by: controller)
    let store = client.store(for: query)
    _ = client.store(for: query)
    controller.count.withLock { expectNoDifference($0, 1) }
    _ = store
  }

  @Test("Resets Query State From Store Through Path")
  func resetQueryStateFromStoreThroughPath() async throws {
    let client = OperationClient()
    let query = PathableQuery(value: 10, path: [1, 2])
    let store = client.store(for: query)
    try await store.fetch()

    let opaqueStore = try #require(client.stores(matching: [1]).first)
    expectNoDifference(store.currentValue, 10)
    opaqueStore.resetState()
    expectNoDifference(store.currentValue, nil)
  }

  @Test("Mutate OpaqueStore Entries")
  func mutateOpaqueStoreEntries() {
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let q2 = PathableQuery(value: 2, path: [1, 3]).defaultValue(20)
    let q3 = PathableQuery(value: 3, path: [2, 4]).defaultValue(30)
    let q4 = PathableQuery(value: 3, path: [2, 5]).defaultValue(40)
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)

    client.withStores(matching: [1]) { entries, createStore in
      expectNoDifference(entries.count, 2)
      entries[q1.path]?.uncheckedSetCurrentValue(50)
      entries.update(OpaqueOperationStore(erasing: createStore(for: q4)))
      entries.removeValue(forPath: q2.path)
    }

    expectNoDifference(client.stores(matching: []).count, 3)
    expectNoDifference(client.store(for: q1).currentValue, 50)
    expectNoDifference(client.store(with: q2.path) == nil, true)
    expectNoDifference(client.store(for: q4).currentValue, 40)
  }

  @Test("Mutate Store Entries")
  func mutateStoreEntries() {
    let client = OperationClient()
    let q1 = TaggedPathableQuery(value: 1, path: [1, 2]).defaultValue(10)
    let q2 = TaggedPathableQuery(value: 2, path: [1, 3]).defaultValue(20)
    let q3 = TaggedPathableQuery(value: "blob", path: [1, 4]).defaultValue("blob")
    let q4 = TaggedPathableQuery(value: 3, path: [2, 4]).defaultValue(30)
    let q5 = TaggedPathableQuery(value: 3, path: [2, 5]).defaultValue(40)
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)
    _ = client.store(for: q4)

    client.withStores(
      matching: [1],
      of: TaggedPathableQuery<Int>.Default.State.self
    ) { entries, createStore in
      expectNoDifference(entries.count, 2)
      entries[q1.path]?.currentValue = 50
      entries.update(createStore(for: q5))
      entries.removeValue(forPath: q2.path)
    }

    expectNoDifference(client.stores(matching: []).count, 4)
    expectNoDifference(client.store(for: q1).currentValue, 50)
    expectNoDifference(client.store(with: q2.path) == nil, true)
    expectNoDifference(client.store(for: q5).currentValue, 40)
  }

  @Test("Nested WithStores")
  func nestedWithStores() {
    let client = OperationClient()
    let isEmpty = client.withStores(matching: OperationPath()) { _, _ in
      client.withStores(matching: OperationPath()) { stores, c in
        stores.isEmpty
      }
    }
    expectNoDifference(isEmpty, true)
  }

  @Test("Subscribe On Added Fires When Store Is Created After Subscription")
  func subscribeOnAddedFiresWhenStoreIsCreatedAfterSubscription() async throws {
    let client = OperationClient()
    let addedStores = RecursiveLock(OperationPathableCollection<OperationStore<TestQuery.State>>())
    let subscription = client.subscribe(
      state: TestQuery.State.self,
      onChange: { change in
        addedStores.withLock { stores in
          for store in change.storesAdded {
            stores.update(store)
          }
        }
      }
    )

    let store = client.store(for: TestQuery())
    let stores = addedStores.withLock { $0 }
    expectNoDifference(stores.count, 1)
    expectNoDifference(stores.first === store, true)
    _ = subscription
  }

  @Test("Subscribe On Added Does Not Fire For Stores Created Before Subscription")
  func subscribeOnAddedDoesNotFireForStoresCreatedBeforeSubscription() async throws {
    let client = OperationClient()
    _ = client.store(for: TestQuery())

    let addedStores = RecursiveLock(OperationPathableCollection<OperationStore<TestQuery.State>>())
    let subscription = client.subscribe(
      state: TestQuery.State.self,
      onChange: { change in
        addedStores.withLock { stores in
          for store in change.storesAdded {
            stores.update(store)
          }
        }
      }
    )

    let stores = addedStores.withLock { $0 }
    expectNoDifference(stores.count, 0)
    _ = subscription
  }

  @Test("Subscribe On Removed Fires When Store Is Cleared")
  func subscribeOnRemovedFiresWhenStoreIsCleared() async throws {
    let client = OperationClient()
    let q1 = TaggedPathableQuery(value: 1, path: [1, 2])
    let store = client.store(for: q1)

    let removedStores = RecursiveLock(
      OperationPathableCollection<OperationStore<TaggedPathableQuery<Int>.State>>()
    )
    let subscription = client.subscribe(
      state: TaggedPathableQuery<Int>.State.self,
      onChange: { change in
        removedStores.withLock { stores in
          for store in change.storesRemoved {
            stores.update(store)
          }
        }
      }
    )

    client.clearStore(with: q1.path)
    let stores = removedStores.withLock { $0 }
    expectNoDifference(stores.count, 1)
    expectNoDifference(stores.first === store, true)
    _ = subscription
  }

  @Test("Subscribe On Removed Fires When Stores Are Cleared Via Matching Path")
  func subscribeOnRemovedFiresWhenStoresAreClearedViaMatchingPath() async throws {
    let client = OperationClient()
    let q1 = TaggedPathableQuery(value: 1, path: [1, 2])
    let q2 = TaggedPathableQuery(value: 2, path: [1, 3])
    let q3 = TaggedPathableQuery(value: 3, path: [2, 4])
    _ = client.store(for: q1)
    let store2 = client.store(for: q2)
    _ = client.store(for: q3)

    let removedStores = RecursiveLock(
      OperationPathableCollection<OperationStore<TaggedPathableQuery<Int>.State>>()
    )
    let subscription = client.subscribe(
      state: TaggedPathableQuery<Int>.State.self,
      onChange: { change in
        removedStores.withLock { stores in
          for store in change.storesRemoved {
            stores.update(store)
          }
        }
      }
    )

    client.clearStores(matching: [1])
    let stores = removedStores.withLock { $0 }
    expectNoDifference(stores.count, 2)
    expectNoDifference(stores.contains(where: { $0 === store2 }), true)
    _ = subscription
  }

  @Test("Subscribe Matching Filters Added And Removed Stores By Path Prefix")
  func subscribeMatchingFiltersAddedAndRemovedStoresByPathPrefix() async throws {
    let client = OperationClient()
    let matchingQuery = TaggedPathableQuery(value: 1, path: [1, 2])
    let nonMatchingQuery = TaggedPathableQuery(value: 2, path: [2, 3])

    let addedStores = RecursiveLock(
      OperationPathableCollection<OperationStore<TaggedPathableQuery<Int>.State>>()
    )
    let removedStores = RecursiveLock(
      OperationPathableCollection<OperationStore<TaggedPathableQuery<Int>.State>>()
    )
    let subscription = client.subscribe(
      matching: [1],
      state: TaggedPathableQuery<Int>.State.self,
      onChange: { change in
        addedStores.withLock { stores in
          for store in change.storesAdded {
            stores.update(store)
          }
        }
        removedStores.withLock { stores in
          for store in change.storesRemoved {
            stores.update(store)
          }
        }
      }
    )

    let matchingStore = client.store(for: matchingQuery)
    let nonMatchingStore = client.store(for: nonMatchingQuery)
    client.clearStore(with: matchingQuery.path)
    client.clearStore(with: nonMatchingQuery.path)

    let storesAdded = addedStores.withLock { $0 }
    let storesRemoved = removedStores.withLock { $0 }
    expectNoDifference(storesAdded.count, 1)
    expectNoDifference(storesAdded.first === matchingStore, true)
    expectNoDifference(storesAdded.contains(where: { $0 === nonMatchingStore }), false)
    expectNoDifference(storesRemoved.count, 1)
    expectNoDifference(storesRemoved.first === matchingStore, true)
    expectNoDifference(storesRemoved.contains(where: { $0 === nonMatchingStore }), false)
    _ = subscription
  }

  @Test("Subscribe Only Receives Stores Of Specified State Type")
  func subscribeOnlyReceivesStoresOfSpecifiedStateType() async throws {
    let client = OperationClient()
    _ = client.store(for: TaggedPathableQuery(value: 1, path: [1, 2]))
    _ = client.store(for: TaggedPathableQuery(value: 2, path: [2, 3]))

    let intAdded = RecursiveLock(
      OperationPathableCollection<OperationStore<TaggedPathableQuery<Int>.State>>()
    )
    let stringAdded = RecursiveLock(
      OperationPathableCollection<OperationStore<TaggedPathableQuery<String>.State>>()
    )
    let intSubscription = client.subscribe(
      state: TaggedPathableQuery<Int>.State.self,
      onChange: { change in
        intAdded.withLock { stores in
          for store in change.storesAdded {
            stores.update(store)
          }
        }
      }
    )
    let stringSubscription = client.subscribe(
      state: TaggedPathableQuery<String>.State.self,
      onChange: { change in
        stringAdded.withLock { stores in
          for store in change.storesAdded {
            stores.update(store)
          }
        }
      }
    )

    expectNoDifference(intAdded.withLock { $0.count }, 0)
    expectNoDifference(stringAdded.withLock { $0.count }, 0)

    _ = client.store(for: TaggedPathableQuery(value: 3, path: [3, 4]))
    expectNoDifference(intAdded.withLock { $0.count }, 1)
    expectNoDifference(stringAdded.withLock { $0.count }, 0)

    _ = client.store(for: TaggedPathableQuery(value: "foo", path: [3, 5]))
    expectNoDifference(intAdded.withLock { $0.count }, 1)
    expectNoDifference(stringAdded.withLock { $0.count }, 1)
    _ = intSubscription
    _ = stringSubscription
  }

  @Test("Typed Subscribe Wraps Opaque Subscribe Correctly")
  func typedSubscribeWrapsOpaqueSubscribeCorrectly() async throws {
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2])

    let opaqueAdded = RecursiveLock(OperationPathableCollection<OpaqueOperationStore>())
    let typedAdded = RecursiveLock(OperationPathableCollection<OperationStore<QueryState<Int, any Error>>>())
    let opaqueSubscription = client.subscribe { change in
      opaqueAdded.withLock { stores in
        for store in change.storesAdded {
          stores.update(store)
        }
      }
    }
    let typedSubscription = client.subscribe(
      state: QueryState<Int, any Error>.self,
      onChange: { change in
        typedAdded.withLock { stores in
          for store in change.storesAdded {
            stores.update(store)
          }
        }
      }
    )

    let store = client.store(for: q1)

    expectNoDifference(opaqueAdded.withLock { $0.count }, 1)
    expectNoDifference(typedAdded.withLock { $0.count }, 1)
    expectNoDifference(
      opaqueAdded.withLock { $0.first?.base as? OperationStore<QueryState<Int, any Error>> } === store,
      true
    )
    expectNoDifference(typedAdded.withLock { $0.first } === store, true)
    _ = opaqueSubscription
    _ = typedSubscription
  }

  @Test("Subscribe On Removed Fires When All Stores Are Cleared")
  func subscribeOnRemovedFiresWhenAllStoresAreCleared() async throws {
    let client = OperationClient()
    let q1 = PathableQuery(value: 1, path: [1, 2])
    let q2 = PathableQuery(value: 2, path: [2, 3])
    _ = client.store(for: q1)
    let store2 = client.store(for: q2)

    let removedStores = RecursiveLock(OperationPathableCollection<OperationStore<QueryState<Int, any Error>>>())
    let subscription = client.subscribe(
      state: QueryState<Int, any Error>.self,
      onChange: { change in
        removedStores.withLock { stores in
          for store in change.storesRemoved {
            stores.update(store)
          }
        }
      }
    )

    client.clearStores()
    let stores = removedStores.withLock { $0 }
    expectNoDifference(stores.count, 2)
    expectNoDifference(stores.contains(where: { $0 === store2 }), true)
    _ = subscription
  }

  @Test("Subscribe On Added Fires When Multiple Stores Created Via WithStores")
  func subscribeOnAddedFiresWhenMultipleStoresCreatedViaWithStores() async throws {
    let client = OperationClient()
    let q1 = TaggedPathableQuery(value: 1, path: [1, 2])
    let q2 = TaggedPathableQuery(value: 2, path: [1, 3])
    let q3 = TaggedPathableQuery(value: 3, path: [2, 4])

    let addedStores = RecursiveLock(
      OperationPathableCollection<OperationStore<TaggedPathableQuery<Int>.State>>()
    )
    let subscription = client.subscribe(
      state: TaggedPathableQuery<Int>.State.self,
      onChange: { change in
        addedStores.withLock { stores in
          for store in change.storesAdded {
            stores.update(store)
          }
        }
      }
    )

    client.withStores(matching: []) { entries, createStore in
      entries.update(OpaqueOperationStore(erasing: createStore(for: q1)))
      entries.update(OpaqueOperationStore(erasing: createStore(for: q2)))
      entries.update(OpaqueOperationStore(erasing: createStore(for: q3)))
    }

    let stores = addedStores.withLock { $0 }
    expectNoDifference(stores.count, 3)
    _ = subscription
  }

  @Test("Subscribe On Removed Fires When Multiple Stores Removed Via WithStores")
  func subscribeOnRemovedFiresWhenMultipleStoresRemovedViaWithStores() async throws {
    let client = OperationClient()
    let q1 = TaggedPathableQuery(value: 1, path: [1, 2])
    let q2 = TaggedPathableQuery(value: 2, path: [1, 3])
    let q3 = TaggedPathableQuery(value: 3, path: [2, 4])
    let q4 = TaggedPathableQuery(value: 4, path: [2, 5])
    _ = client.store(for: q1)
    _ = client.store(for: q2)
    _ = client.store(for: q3)
    let store4 = client.store(for: q4)

    let removedStores = RecursiveLock(
      OperationPathableCollection<OperationStore<TaggedPathableQuery<Int>.State>>()
    )
    let subscription = client.subscribe(
      state: TaggedPathableQuery<Int>.State.self,
      onChange: { change in
        removedStores.withLock { stores in
          for store in change.storesRemoved {
            stores.update(store)
          }
        }
      }
    )

    client.withStores(matching: [1]) { entries, _ in
      entries.removeValue(forPath: q1.path)
      entries.removeValue(forPath: q2.path)
    }

    let stores = removedStores.withLock { $0 }
    expectNoDifference(stores.count, 2)
    expectNoDifference(stores.contains(where: { $0 === store4 }), false)
    _ = subscription
  }

  @Test("Subscribe On Added Fires Through Typed WithStores")
  func subscribeOnAddedFiresThroughTypedWithStores() async throws {
    let client = OperationClient()
    let q1 = TaggedPathableQuery(value: 1, path: [1, 2])
    let q2 = TaggedPathableQuery(value: 2, path: [1, 3])

    let addedStores = RecursiveLock(
      OperationPathableCollection<OperationStore<TaggedPathableQuery<Int>.State>>()
    )
    let subscription = client.subscribe(
      state: TaggedPathableQuery<Int>.State.self,
      onChange: { change in
        addedStores.withLock { stores in
          for store in change.storesAdded {
            stores.update(store)
          }
        }
      }
    )

    client.withStores(matching: [], of: TaggedPathableQuery<Int>.State.self) { entries, createStore in
      entries.update(createStore(for: q1))
      entries.update(createStore(for: q2))
    }

    let stores = addedStores.withLock { $0 }
    expectNoDifference(stores.count, 2)
    _ = subscription
  }

  @Test("Subscribe On Change Does Not Fire When WithStores Makes No Changes")
  func subscribeOnChangeDoesNotFireWhenWithStoresMakesNoChanges() async throws {
    let client = OperationClient()
    _ = client.store(for: TaggedPathableQuery(value: 1, path: [1, 2]))

    let changeCount = RecursiveLock(0)
    let subscription = client.subscribe(
      state: TaggedPathableQuery<Int>.State.self,
      onChange: { _ in
        changeCount.withLock { $0 += 1 }
      }
    )

    client.withStores(matching: [1], of: TaggedPathableQuery<Int>.State.self) { stores, _ in
      expectNoDifference(stores.count, 1)
    }

    changeCount.withLock { expectNoDifference($0, 0) }
    _ = subscription
  }

  @Test("Subscribe On Removed Fires Through Typed WithStores")
  func subscribeOnRemovedFiresThroughTypedWithStores() async throws {
    let client = OperationClient()
    let q1 = TaggedPathableQuery(value: 1, path: [1, 2])
    let q2 = TaggedPathableQuery(value: 2, path: [1, 3])
    _ = client.store(for: q1)
    let store2 = client.store(for: q2)

    let removedStores = RecursiveLock(
      OperationPathableCollection<OperationStore<TaggedPathableQuery<Int>.State>>()
    )
    let subscription = client.subscribe(
      state: TaggedPathableQuery<Int>.State.self,
      onChange: { change in
        removedStores.withLock { stores in
          for store in change.storesRemoved {
            stores.update(store)
          }
        }
      }
    )

    _ = client.withStores(matching: [], of: TaggedPathableQuery<Int>.State.self) { entries, _ in
      entries.removeValue(forPath: q2.path)
    }

    let stores = removedStores.withLock { $0 }
    expectNoDifference(stores.count, 1)
    expectNoDifference(stores.first === store2, true)
    _ = subscription
  }
}

private final class CountingController<State: OperationState>: OperationController, Sendable
where State: Sendable {
  let count = RecursiveLock(0)

  func control(with controls: OperationControls<State>) -> OperationSubscription {
    self.count.withLock { $0 += 1 }
    return .empty
  }
}
