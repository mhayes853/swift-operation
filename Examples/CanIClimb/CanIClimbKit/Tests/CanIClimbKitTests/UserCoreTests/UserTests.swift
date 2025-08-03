import CanIClimbKit
import CustomDump
import Foundation
import Testing

@Suite("User tests")
struct UserTests {
  @Suite("User.Name tests")
  struct UserNameTests {
    @Test(
      "Parses Name Components",
      arguments: [
        ("", nil),
        ("New Name", PersonNameComponents(givenName: "New", familyName: "Name")),
        ("123", PersonNameComponents(givenName: "123")),
        ("Blob", PersonNameComponents(givenName: "Blob"))
      ]
    )
    func parses(name: String, components: PersonNameComponents?) {
      let name = User.Name(name)
      expectNoDifference(name?.components, components)
    }
  }
}
