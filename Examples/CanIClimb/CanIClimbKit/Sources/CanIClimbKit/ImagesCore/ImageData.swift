import SwiftUI

// MARK: - ImageData

public struct ImageData: Sendable {
  public let data: Data
  public let image: PlatformImage

  public init(data: Data) throws {
    guard let image = PlatformImage(data: data) else { throw LoadingError() }
    self.image = image
    self.data = data
  }
}

// MARK: - Hashable

extension ImageData: Hashable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.data == rhs.data
  }
}

// MARK: - Loading Error

extension ImageData {
  public struct LoadingError: Error {
    public init() {}
  }
}

// MARK: - SwiftUI

extension ImageData: Transferable {
  public static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(importedContentType: .image) { try Self(data: $0) }
  }
}

extension ImageData {
  @MainActor
  public init(view: some View) throws {
    let renderer = ImageRenderer(content: view)
    guard let data = renderer.platformImage?.jpegData(compressionQuality: 1) else {
      throw LoadingError()
    }
    try self.init(data: data)
  }
}

extension ImageData {
  @MainActor public static let circle = try! Self(
    view: Circle().frame(width: 20, height: 20)
  )
  @MainActor public static let rectangle = try! Self(
    view: Rectangle().frame(width: 20, height: 20)
  )
}
