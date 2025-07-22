import SwiftUI

#if !os(macOS)
  public typealias PlatformImage = UIImage
#else
  public typealias PlatformImage = NSImage
#endif

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
