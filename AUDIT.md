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

Result after review: 578 Swift Testing tests passed with 25 pre-existing known issues;
26 XCTest tests passed without failures. All five audit known-issue reproductions now pass
as ordinary regressions following the decisions below.
Macro expansion and consumer tests ran on this host. Apple-only and browser/WASM runtime
behavior was not exercised.

Swift 6.1.3 also passed 574 Swift Testing tests (25 pre-existing known issues) and 26
XCTest tests in an isolated copy. Exit-test availability accounts for part of the count
difference. Its run used JavaScriptKit 0.50.0, now pinned in `Package.resolved` as required
by the manifest's Swift 6.1 compatibility branch. Newer toolchains resolve a newer release.
An independent arithmetic check also matched 10,062 generated integer scaling results
against `Int128` reference calculations.

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

## Follow-up decisions implemented

### Recursive callback locking — `1134814`

Both subscription paths now use recursive locks, as requested. Callback delivery stays
serialized. Short nested state accesses snapshot subscribers or clear the cancellation handler
before invoking callbacks, so recursive calls do not overlap an `inout` access. Cancellation
still invokes its handler exactly once. Subscription changes during a notification affect
subsequent notifications; the current notification uses its captured subscriber snapshot.

Regressions now live in [OperationSubscriptionTests](Tests/OperationTests/OperationSubscriptionTests.swift),
including subscriber count reads, recursive cancellation, and cancellation during notification.
Bounded child processes are used on Swift 6.2 and newer to catch future deadlocks.

### Success wins timestamp ties — `42a2ebb`

The status calculation prioritizes a successful value whenever value and error timestamps
are equal, regardless of arrival order. Both arrival orders are tested in the existing
[OperationStatusTests](Tests/OperationTests/OperationStatusTests.swift) suite.

### Exact integer duration arithmetic — `25aef56`

Integer multiplication and division now operate on seconds and attoseconds with signed
full-width integer arithmetic. Division truncates fractions of an attosecond toward zero.
Division by zero and unrepresentable results still trap. This avoids an unconditional
`Int128` dependency on older Apple deployment targets.

Precision, carry, sign, remainder, and component-boundary tests are in the existing
[OperationDurationTests](Tests/OperationTests/OperationDurationTests.swift) suite.
Floating-point factories and duration-to-duration ratios retain their existing behavior.

### Test organization — `c7b6238`, `0535a71`

The timer regression now exercises public `URLConnectionObserver` behavior with a controlled
clock, without `@testable`. Path, pagination, status, subscription, and duration regressions
were merged into their existing suites. Lock lifetime tests are top-level tests. Audit tests
use Swift 6.1-compatible `@Test("Display Name")` attributes with ordinary function identifiers.

### Swift 6.1 test execution — `e0345a0`, `11f63eb`

The timeout fixtures used `Task.sleep(nanoseconds: .max)`, which returns immediately on
Swift 6.1.3 on Linux. They now use the existing cancellation-aware `Task.never()` helper.
The JavaScriptKit pin was corrected to 0.50.0 so Swift 6.1 can load the dependency manifest;
the prior 0.58.0 pin required Swift tools 6.2 before version constraints could be applied.

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
