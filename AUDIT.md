# Library bug audit

## Scope and validation

Reviewed the library's paths, state and store machinery, clients, pagination, mutations,
execution modifiers, tasks, durations, subscriptions, run specifications, macros, and sharing
and browser integrations. Three non-Astra agents performed bounded audits; the coordinating
agent reviewed findings, rejected false positives, ran tests, and committed fixes separately.
Examples were outside this pass. This is not an exhaustive concurrency or platform audit.

Validated on Linux with Swift 6.3.3:

```sh
swift test --disable-experimental-prebuilts --traits SwiftOperationLogging
```

Result: 574 Swift Testing tests passed with 30 known issues; 26 XCTest tests passed without
failures. Five known issues were added by this audit to demonstrate the deferred bugs below.
Macro expansion and consumer tests ran on this host. Apple-only and browser/WASM runtime
behavior was not exercised.

Regressions were observed before fixing path equality/replacement, lock lifetimes, client
context replacement, pagination context/task naming, timer scheduling, optional macro
compilation, and integer duration factories. The original integer factories crashed for both
wide and narrow inputs. Duration decoding normalization failed before its fix; overflow
rejection was added alongside normalization.

## Fixed

| Commit | Problem and resulting behavior |
| --- | --- |
| `1cb7b8a` | Single-element paths compared equal to longer paths sharing their first element. Equality now checks length. |
| `6def78e` | Range replacement/insertion discarded additional elements for empty and single-element paths. Every replacement element is retained. |
| `4480c19` | Both internal lock types freed allocated storage without destroying its value. Stored references are now released. |
| `8290914` | Replacing a client's default context dropped the link to that client. New stores retain the correct weak client link. |
| `f2b6845` | A delayed timer iteration could compute another deadline in the past. It now schedules the next due interval. |
| `8e3031e` | Context-entry optional detection inspected punctuation anywhere in a type and rejected `Swift.Optional`. Detection now follows type structure. |
| `2909d19` | A fresh caller-supplied pagination context lacked metadata, making next/previous/refetch-all operations fetch the initial page. Metadata is initialized and subscriptions preserved. |
| `dff223a` | Refetch-all tasks overwrote custom task names. Explicit names are preserved. |
| `d0b9692` | Decoded duration components could violate normalization invariants. Decoding normalizes components and throws on overflow. |
| `739da9c` | Integer subsecond duration factories narrowed wide values too early and performed modulo with divisors unrepresentable by narrow types. They now support both narrow and wide representable inputs. |

## Confirmed bugs requiring discussion

These remain unfixed, with `withKnownIssue` regressions. Unexpectedly fixing one makes its
known-issue expectation fail, so the tests must be updated when its production fix lands.

### Callback reentrancy deadlocks

- `OperationSubscriptions.forEach` invokes subscribers under a nonrecursive lock. A callback
  reading `MockNetworkObserver.subscriberCount` deadlocks. Adding/removing subscribers can
  encounter the same lock.
- `OperationSubscription` invokes its cancellation handler under a nonrecursive lock. A
  handler cancelling the same subscription deadlocks.
- Evidence: [OperationSubscriptionDeadlockTests](Tests/OperationTests/OperationSubscriptionDeadlockTests.swift).
  Child processes exit after a one-second watchdog instead of hanging the suite.
- Discussion: detach cancellation work from the lock, and decide notification semantics when
  subscribers are added or removed during delivery before moving delivery outside the lock.

### Equal timestamps lose the latest successful status

An error followed by a successful update at the same clock time does not produce a successful
status. The comparison of update dates cannot distinguish their order; the error has been
cleared, so the successful state can appear idle.

- Evidence: [OperationStatusTimestampTests](Tests/OperationTests/OperationStatusTimestampTests.swift).
- Discussion: define update ordering independently of wall-clock timestamps, including what
  custom `OperationState` conformances must provide.

### Duration arithmetic loses precision

Multiplying or dividing a duration by integer one loses its attosecond component because the
implementation converts through `Double`.

- Evidence: [OperationDurationPrecisionTests](Tests/OperationTests/OperationDurationPrecisionTests.swift).
- Discussion: implement exact component arithmetic and choose an overflow policy. Wide
  floating-point factory inputs also need careful treatment; simply dividing before narrowing
  can introduce whole-second rounding errors. Floating factories were left unchanged.

## Retry semantics

The existing `||` combines bounds independently of predicates. With bounds 1 and 3 and
predicates true and false, it permits three retries (four attempts). This interpretation was
discussed with the user and preserved. An ordinary regression test documents it; it is not
classified as a bug.

## Further leads, not reproduced or fixed

These are source-review observations for follow-up, not verified defects:

- Concurrent runs register handlers in a shared temporary subscription collection; investigate
  whether per-call mutation/pagination callbacks receive another run's events.
- Client store-added notifications occur before cache insertion; investigate reentrant lookup
  and clearing from notification handlers.
- Hydrated pagination values do not initialize page cursors, and concurrent same-direction
  fetches may capture the same cursor. Define the desired cursor/deduplication behavior.
- Value-type network observers are bridged to `AnyObject` for sharing-key identity. Decide how
  value observers should be identified.
- Macro validation handles qualified and compound types inconsistently in reserved arguments
  and custom paths. Structural matching and diagnostic policy need a separate review.
- Exponential/Fibonacci backoff overflow and zero/negative timer intervals need explicit policies.

Two candidate fixes were rejected after review: explicit `_:` call labels compile on the
installed supported Swift toolchain, and current browser visibility events bubble from the
document to the window. Neither production change was retained.
