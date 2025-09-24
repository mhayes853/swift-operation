import Dependencies
import Operation
import SwiftUI
import SwiftUINavigation
import UIKitNavigation

// MARK: - Query Modifier

extension OperationRequest {
  public func alerts(
    success: AlertState<Never>? = nil,
    failure: AlertState<Never>? = nil
  ) -> ModifiedOperation<Self, _AlertStateModifier<Self>> {
    self.alerts(success: { _ in success }, failure: { _ in failure })
  }

  public func alerts(
    success: @escaping @Sendable (Value) -> AlertState<Never>? = { _ in nil },
    failure: @escaping @Sendable (any Error) -> AlertState<Never>? = { _ in nil }
  ) -> ModifiedOperation<Self, _AlertStateModifier<Self>> {
    self.modifier(_AlertStateModifier(successAlert: success, failureAlert: failure))
  }
}

public struct _AlertStateModifier<Operation: OperationRequest>: OperationModifier, Sendable {
  let successAlert: @Sendable (Operation.Value) -> AlertState<Never>?
  let failureAlert: @Sendable (any Error) -> AlertState<Never>?

  public func run(
    isolation: isolated (any Actor)?,
    in context: OperationContext,
    using query: Operation,
    with continuation: OperationContinuation<Operation.Value, Operation.Failure>
  ) async throws(Operation.Failure) -> Operation.Value {
    @Dependency(\.notificationCenter) var center
    do {
      let value = try await query.run(isolation: isolation, in: context, with: continuation)
      if let successAlert = self.successAlert(value) {
        await center.post(OperationAlertMessage(alert: successAlert))
      }
      return value
    } catch {
      if context.isLastRunAttempt, let failureAlert = self.failureAlert(error) {
        await center.post(OperationAlertMessage(alert: failureAlert))
      }
      throw error
    }
  }
}

// MARK: - Notification

public struct OperationAlertMessage: NotificationCenter.MainActorMessage {
  public typealias Subject = AnyObject

  public static var name: Notification.Name {
    Notification.Name("OperationAlertMessageNotification")
  }

  public let alert: AlertState<Never>
}

// MARK: - Observe View Modifier

extension View {
  public func observeOperationAlerts() -> some View {
    self.modifier(ObserveOperationAlertsModifier())
  }
}

private struct ObserveOperationAlertsModifier: ViewModifier {
  @State private var token: NotificationCenter.ObservationToken?
  @Dependency(\.notificationCenter) var center

  func body(content: Content) -> some View {
    content
      .onAppear {
        self.token = self.center.addObserver(for: OperationAlertMessage.self) { message in
          #if os(iOS)
            // NB: Present through UIKit directly on iOS due to SwiftUI dismissing children sheets
            // when an alert is presented from a parent view.
            let alert = GlobalAlertController.withOkButton(state: message.alert)
            alert.present()
          #endif
        }
      }
      .onDisappear {
        guard let token = self.token else { return }
        self.center.removeObserver(token)
      }
  }
}
