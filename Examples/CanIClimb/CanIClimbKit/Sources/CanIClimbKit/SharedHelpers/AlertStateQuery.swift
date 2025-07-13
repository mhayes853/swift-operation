import Dependencies
import Query
import SwiftUI
import SwiftUINavigation
import UIKitNavigation

// MARK: - Query Modifier

extension QueryRequest {
  public func alerts(
    success: AlertState<Never>? = nil,
    failure: AlertState<Never>? = nil
  ) -> ModifiedQuery<Self, _AlertStateModifier<Self>> {
    self.modifier(_AlertStateModifier(successAlert: success, failureAlert: failure))
  }
}

public struct _AlertStateModifier<Query: QueryRequest>: QueryModifier {
  let successAlert: AlertState<Never>?
  let failureAlert: AlertState<Never>?

  public func fetch(
    in context: QueryContext,
    using query: Query,
    with continuation: QueryContinuation<Query.Value>
  ) async throws -> Query.Value {
    @Dependency(\.notificationCenter) var center
    do {
      let value = try await query.fetch(in: context, with: continuation)
      if let successAlert {
        await center.post(QueryAlertMessage(alert: successAlert))
      }
      return value
    } catch {
      let isLastRetry = context.queryRetryIndex >= context.queryMaxRetries
      if let failureAlert, isLastRetry {
        await center.post(QueryAlertMessage(alert: failureAlert))
      }
      throw error
    }
  }
}

// MARK: - Notification

public struct QueryAlertMessage: NotificationCenter.MainActorMessage {
  public typealias Subject = AnyObject

  public static var name: Notification.Name {
    Notification.Name("QueryAlertMessageNotification")
  }

  public let alert: AlertState<Never>
}

// MARK: - View Modifier

extension View {
  public func observeQueryAlerts() -> some View {
    self.modifier(ObserveQueryAlertsModifier())
  }
}

private struct ObserveQueryAlertsModifier: ViewModifier {
  @State private var alert: AlertState<Never>?
  @State private var token: NotificationCenter.ObservationToken?
  @Dependency(\.notificationCenter) var center

  func body(content: Content) -> some View {
    content
      .onAppear {
        self.token = self.center.addObserver(for: QueryAlertMessage.self) { message in
          #if os(macOS)
            self.alert = message.alert
          #else
            // NB: Present through UIKit directly on iOS due to SwiftUI dismissing children sheets
            // when an alert is presented from a parent view.
            let alert = CanIClimbAlertController.withOkButton(state: message.alert)
            alert.present()
          #endif
        }
      }
      .onDisappear {
        guard let token = self.token else { return }
        self.center.removeObserver(token)
      }
      .alert(self.$alert)
  }
}
