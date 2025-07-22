import SwiftUI

// MARK: - PlatformImage

#if !os(macOS)
  public typealias PlatformImage = UIImage
#else
  public typealias PlatformImage = NSImage
#endif

// MARK: - ImageRenderer

extension ImageRenderer {
  @MainActor
  public var platformImage: PlatformImage? {
    #if !os(macOS)
      self.uiImage
    #else
      self.nsImage
    #endif
  }
}

// MARK: - SwiftUI Image

extension Image {
  public init(platformImage: PlatformImage) {
    #if !os(macOS)
      self.init(uiImage: platformImage)
    #else
      self.init(nsImage: platformImage)
    #endif
  }
}

// MARK: - JPEG Data

#if os(macOS)
  extension NSImage {
    public func jpegData(compressionQuality: CGFloat) -> Data? {
      guard let tiff = self.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else {
        return nil
      }
      return bitmap.representation(
        using: .jpeg,
        properties: [.compressionFactor: compressionQuality]
      )
    }
  }
#endif
