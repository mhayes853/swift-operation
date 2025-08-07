import CoreLocation
import MapKit
import SwiftUI

// MARK: - Annotation

extension Annotation where Label == Text, Content == MountainAnnotationView {
  public init(mountain: Mountain, onTapped: @escaping () -> Void) {
    self.init(mountain.name, coordinate: CLLocationCoordinate2D(coordinate: mountain.coordinate)) {
      MountainAnnotationView(mountain: mountain, onTapped: onTapped)
    }
  }
}

// MARK: - MountainAnnotationView

public struct MountainAnnotationView: View {
  let mountain: Mountain
  let onTapped: () -> Void

  public var body: some View {
    ImageDataView(url: mountain.image.url) { status in
      ZStack {
        switch status {
        case .result(.success(let image)):
          image
            .resizable()
            .scaledToFill()
        default:
          ZStack {
            Circle()
              .fill(.gray.gradient)
            SpinnerView()
          }
        }
        Circle()
          .stroke(.white, lineWidth: 2)
      }
      .frame(width: 45, height: 45)
      .clipShape(Circle())
    }
    .onTapGesture {
      self.onTapped()
    }
  }
}
