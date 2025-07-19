import IssueReporting
import SharingQuery
import SwiftUI
import SwiftUINavigation

// MARK: - FormCaseStudy

struct FormCaseStudy: CaseStudy {
  let title: LocalizedStringKey = "Forms"
  let description: LocalizedStringKey = """
    Most applications utilize some kind of form to allow users to create or update data. You can \
    use the `MutationRequest` protocol to power the submission for such forms. Alongside automatic \
    retry logic, you can also look into the history of previous submissions to detect a known bad \
    input.

    This example simulates a user updating their name through a form. The form uses the history of \
    every subsmission on its mutation to detect whether or not a previously entered name is known \
    to be taken. If so, it doesn't allow the user to resubmit that name.
    """

  @State private var model = FormModel()

  var content: some View {
    Group {
      Section {
        TextField("Enter a name", text: self.$model.name.animation())
      } header: {
        Text("Update Name")
      } footer: {
        if self.model.submissionStatus == .nameTaken {
          Text("Name has been taken.").foregroundStyle(.red)
        }
      }

      Section {
        Button {
          Task {
            guard let name = self.model.submissionStatus[case: \.submittable] else { return }
            try await self.model.submit(name: name)
          }
        } label: {
          HStack {
            if self.model.$update.isLoading {
              ProgressView()
            } else {
              Image(systemName: "arrow.up.right")
            }
            Text("Submit Name")
          }
        }
        .disabled(!self.model.submissionStatus.is(\.submittable) || self.model.$update.isLoading)
      } footer: {
        Text(
          """
          Enter any of these names to trigger an error when submitting: \
          \(takenNames.formatted(.list(type: .or))).
          """
        )
      }
    }
    .alert(self.$model.alert) { _ in }
  }
}

// MARK: - FormModel

@MainActor
@Observable
final class FormModel {
  @ObservationIgnored
  @SharedQuery(FormName.updateMutation, animation: .bouncy) var update

  var name = ""
  var alert: AlertState<AlertAction>?
}

extension FormModel {
  @CasePathable
  enum SubmissionStatus: Hashable, Sendable {
    case empty
    case submittable(FormName)
    case nameTaken
  }

  var submissionStatus: SubmissionStatus {
    guard let name = FormName(rawValue: self.name) else { return .empty }
    let isNameTaken = self.$update.history
      .contains {
        $0.arguments.name.rawValue.lowercased() == self.name.lowercased()
          && $0.currentResult[case: \.success] == .nameTaken
      }
    return isNameTaken ? .nameTaken : .submittable(name)
  }
}

extension FormModel {
  func submit(name: FormName) async throws {
    let result = try await self.$update.mutate(with: FormName.UpdateMutation.Arguments(name: name))
    switch result {
    case .nameTaken:
      self.alert = .failure(name: name)
    case .success:
      self.alert = .success(name: name)
    }
  }
}

// MARK: - AlertState

extension FormModel {
  enum AlertAction: Hashable, Sendable {}
}

extension AlertState where Action == FormModel.AlertAction {
  static func success(name: FormName) -> Self {
    Self {
      TextState("Success")
    } message: {
      TextState("Your name was updated to \(name.rawValue)!")
    }
  }

  static func failure(name: FormName) -> Self {
    Self {
      TextState("Failed")
    } message: {
      TextState("\(name.rawValue) has been taken!")
    }
  }
}

// MARK: - Name

struct FormName: Hashable, RawRepresentable {
  var rawValue: String

  init?(rawValue: String) {
    guard !rawValue.isEmpty else { return nil }
    self.rawValue = rawValue
  }
}

// MARK: - Mutation

private let takenNames = ["blob", "joe", "ashley", "maria", "sam", "james"]

extension FormName {
  static let updateMutation = UpdateMutation()

  enum UpdateResult: Hashable, Sendable {
    case success
    case nameTaken
  }

  struct UpdateMutation: MutationRequest, Hashable {
    struct Arguments: Sendable {
      let name: FormName
    }

    func mutate(
      with arguments: Arguments,
      in context: QueryContext,
      with continuation: QueryContinuation<UpdateResult>
    ) async throws -> UpdateResult {
      try await context.queryDelayer.delay(for: isTesting ? 0 : 0.5)
      if takenNames.contains(where: { $0.lowercased() == arguments.name.rawValue.lowercased() }) {
        return .nameTaken
      } else {
        return .success
      }
    }
  }
}

#Preview {
  NavigationStack {
    FormCaseStudy()
  }
}
