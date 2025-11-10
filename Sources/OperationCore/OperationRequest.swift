// MARK: - OperationRequest

/// An immutable description of asynchronous work.
///
/// ```swift
/// struct WorkflowResponse {
///   // ...
/// }
///
/// extension WorkflowResponse {
///   static var operation: some OperationRequest<WorkflowResponse, any Error> {
///     Self.$operation
///       .retry(limit: 3)
///       .deduplicated()
///       .taskConfiguration { $0.name = "Workflow Run" }
///   }
///
///   @OperationRequest
///   private static func operation() aysnc throws -> WorkflowResponse {
///     // ...
///   }
/// }
/// ```
///
/// There are 3 components to an operation, outside of the code to that runs the workflow itself.
/// 1. The data type it returns.
/// 2. The error type it throws.
/// 3. It's dependencies (including isolation).
///
/// The first 2 components are implemented via that ``Value`` and ``Failure`` associated types
/// respectively.
///
/// The 3rd component is implemented via the ``OperationContext`` and isolation parameter passed to
/// ``run(isolation:in:with:)``. The context is an extensible and type-safe key value store (like
/// `EnvironmentValues` in SwiftUI) that facilitates dependency injection. The isolation parameter
/// represents the current actor-isolation context that the operation is running in.
///
/// Since operations are descriptions of workflows, this enables a world of functionallity that
/// can be implemented on top of a conformance to this protocol. The
/// ``OperationModifier`` protocol allows one to define extensible behavior on top of an operation
/// such as retries, deduplication, and much more.
///
/// ```swift
/// @OperationRequest
/// func myOperation() async throws {
///   // ...
/// }
///
/// let operation = $myOperation
///   .retry(limit: 3)
///   .deduplicated()
/// ```
public protocol OperationRequest<Value, Failure> {
  /// The type this operation returns.
  associatedtype Value

  /// The error type this operation throws.
  associatedtype Failure: Error

  var _debugTypeName: String { get }

  /// Sets up an ``OperationContext`` in preparation for it being passed to
  /// ``run(isolation:in:with:)``.
  ///
  /// This method is called a single time when an ``OperationStore`` or ``OperationRunner`` is
  /// initialized with this operation.
  ///
  /// - Parameter context: The context to setup.
  func setup(context: inout OperationContext)

  /// Runs this operation.
  ///
  /// - Parameters:
  ///   - isolation: The current actor-isolation of this operation run.
  ///   - context: An ``OperationContext`` that is passed to this operation.
  ///   - continuation: An ``OperationContinuation`` that allows you to yield data while this
  ///   operation is still running. See <doc:MultistageOperations> for more.
  /// - Returns: The value returned from this operation.
  func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    with continuation: OperationContinuation<Value, Failure>
  ) async throws(Failure) -> Value
}

extension OperationRequest {
  public func setup(context: inout OperationContext) {
  }

  public var _debugTypeName: String { typeName(Self.self) }
}

// MARK: - StatefulOperationRequest

/// An immutable description of asynchronous work that has state associated with it.
///
/// Stateful operations benefit from a dedicated state management system provided by the library.
/// This system comprises of types such as ``OperationStore``, which manages the state for a stateful
/// operation, and ``OperationClient``, which manages a pool of operation stores.
///
/// Additionally, many modifiers are available in the library that declaratively describe
/// processes to manage the state of an operation. For instance the
/// ``StatefulOperationRequest/rerunOnChange(of:)`` modifier describes when an operation should
/// be rerun based on the statisfication of an ``OperationRunSpecification``.
///
/// The library provides 3 base operation protocols that inherit from this protocol.
/// 1. ``QueryRequest`` describes operations that simply fetch a value in its entirety.
/// 2. ``PaginatedRequest`` describes operations that paginated their results.
/// 3. ``MutationRequest`` describes operations that create, update, or delete data asynchronously
/// (eg. An HTTP POST request).
///
/// This protocol requires an operation to define the type of state that it manages. This type must
/// conform to the ``OperationState`` protocol. ``QueryRequest``, ``PaginatedRequest``, and
/// ``MutationRequest`` have concrete state types that are defined for you, so you will not need
/// to specify a state type when confoming your operation to any of those protocols.
///
/// Since many operation stores are managed within an `OperationClient`, your operation type needs
/// to be uniquely identifiable in order to retrieve the appropriate store within the client. This
/// is implemented through the ``path-6fsa8`` property, which requires you to provide an
/// ``OperationPath`` that uniquely identifies your operation. The path is a special type that
/// enables prefix based pattern matching, see <doc:PatternMatchingAndStateManagement> for more. If
/// your operation conforms to Identifiable or Hashable, the path requirement has a default
/// implementation that uses the identity or hashability of your operation respectively.
public protocol StatefulOperationRequest<State>: OperationRequest
where Value: Sendable, State.OperationValue == Value, State.Failure == Failure {
  /// The state type for your operation.
  associatedtype State: OperationState

  /// an ``OperationPath`` that uniquely identifies your operation.
  ///
  /// If your operation conforms to Hashable or Identifiable, then this requirement is implemented by
  /// default. However, if you want to take advantage of pattern matching, then you'll want to
  /// implement this requirement manually.
  ///
  /// See <doc:PatternMatchingAndStateManagement> for more.
  var path: OperationPath { get }
}

// MARK: - Path Defaults

extension StatefulOperationRequest where Self: Hashable & Sendable {
  public var path: OperationPath {
    OperationPath(self)
  }
}

extension StatefulOperationRequest where Self: Identifiable, ID: Sendable {
  public var path: OperationPath {
    OperationPath(self.id)
  }
}
