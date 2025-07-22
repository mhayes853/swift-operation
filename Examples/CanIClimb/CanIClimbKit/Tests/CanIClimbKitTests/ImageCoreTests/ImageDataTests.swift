import CanIClimbKit
import CustomDump
import SwiftUI
import Testing

@MainActor
@Suite("ImageData tests")
struct ImageDataTests {
  @Test("Throws When Invalid Data", arguments: [Data(), Data("Hello World".utf8)])
  func throwsWhenInvalidData(data: Data) {
    #expect(throws: ImageData.LoadingError.self) {
      _ = try ImageData(data: data)
    }
  }

  @Test("Creates from Valid JPEG Data")
  func createsFromValidJPEGData() throws {
    let renderer = ImageRenderer(
      content: Circle().fill(.red).frame(width: 1, height: 1)
    )
    let rawImageData = try #require(renderer.platformImage?.jpegData(compressionQuality: 1))
    let imageData = try ImageData(data: rawImageData)
    expectNoDifference(rawImageData, imageData.data)
  }
}
