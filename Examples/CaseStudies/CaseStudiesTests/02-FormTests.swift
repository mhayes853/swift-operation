import CustomDump
import Dependencies
import SharingOperation
import Testing

@testable import CaseStudies

@MainActor
@Suite("02-Form tests")
struct FormCaseStudyTests {
  @Test("FormName", arguments: [("blob", "blob"), ("", nil)])
  func formName(rawValue: String, expectedRawValue: String?) async throws {
    expectNoDifference(FormName(rawValue: rawValue)?.rawValue, expectedRawValue)
  }

  @Test("Cannot Submit Invalid Name")
  func cannotSubmitInvalidName() async throws {
    let model = FormModel()
    expectNoDifference(model.submissionStatus, .empty)

    model.name = "foo"
    expectNoDifference(model.submissionStatus, .submittable(FormName(rawValue: "foo")!))
  }

  @Test("Successfully Update Name")
  func successfullyUpdateName() async throws {
    let model = FormModel()
    model.name = "foo"

    let name = try #require(model.submissionStatus[case: \.submittable])
    try await model.submit(name: name)

    expectNoDifference(model.alert, .success(name: name))
  }

  @Test("Unsuccessfully Update Name, Failed Name Becomes Taboo")
  func unsuccessfulyUpdateNameBecomesTaboo() async throws {
    let model = FormModel()
    model.name = "blob"

    let name = try #require(model.submissionStatus[case: \.submittable])
    try await model.submit(name: name)

    expectNoDifference(model.alert, .failure(name: name))
    expectNoDifference(model.submissionStatus, .nameTaken)
    model.alert = nil

    model.name = "foo"
    expectNoDifference(model.submissionStatus.is(\.submittable), true)

    model.name = "blob"
    expectNoDifference(model.submissionStatus, .nameTaken)
  }
}
