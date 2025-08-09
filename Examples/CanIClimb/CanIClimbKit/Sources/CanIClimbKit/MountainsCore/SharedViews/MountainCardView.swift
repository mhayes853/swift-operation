import SwiftUI

// MARK: - MountainCardView

public struct MountainCardView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private let mountain: Mountain

  @ScaledMetric private var cardHeight = CGFloat(200)

  public init(mountain: Mountain) {
    self.mountain = mountain
  }

  public var body: some View {
    Group {
      if self.dynamicTypeSize.isAccessibilitySize {
        VStack {
          CardContentView(mountain: self.mountain)
        }
      } else {
        HStack(alignment: .top, spacing: 20) {
          CardContentView(mountain: self.mountain)
        }
      }
    }
    .padding()
    .background(
      self.colorScheme == .dark
        ? AnyShapeStyle(Color.secondaryBackground)
        : AnyShapeStyle(.background)
    )
    .clipShape(RoundedRectangle(cornerRadius: 30))
    .shadow(color: Color.black.opacity(self.colorScheme == .light ? 0.15 : 0), radius: 15, y: 10)
    .frame(height: self.cardHeight)
  }
}

// MARK: - CardContentView

private struct CardContentView: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let mountain: Mountain

  private var imageSize: CGSize {
    if self.dynamicTypeSize.isAccessibilitySize {
      CGSize(width: .infinity, height: 150.0)
    } else {
      CGSize(width: 150.0, height: .infinity)
    }
  }

  var body: some View {
    let mountainContent = VStack(alignment: .leading) {
      Text(self.mountain.name)
        .lineLimit(2)
        .font(.title3.bold())

      MountainLocationNameLabel(name: self.mountain.location.name)
        .foregroundStyle(.secondary)

      ElevationLabel(elevation: self.mountain.elevation)
        .foregroundStyle(.secondary)

      Spacer()

      MountainDifficultyView(difficulty: self.mountain.difficulty)
    }
    .frame(maxWidth: .infinity, alignment: .leading)

    let image = ImageDataView(url: self.mountain.image.url) { status in
      switch status {
      case .result(.success(let image)):
        image
          .resizable()
          .scaledToFill()
          .frame(maxWidth: self.imageSize.width, maxHeight: self.imageSize.height)
          .clipShape(RoundedRectangle(cornerRadius: 10))
      default:
        ZStack {
          RoundedRectangle(cornerRadius: 10)
            .fill(.gray.gradient)
          SpinnerView()
        }
        .frame(maxWidth: self.imageSize.width, maxHeight: self.imageSize.height)
      }
    }

    if self.dynamicTypeSize.isAccessibilitySize {
      image
      mountainContent
    } else {
      mountainContent
      image
    }
  }
}

#Preview {
  var mountain = Mountain.mock2
  let _ = mountain.difficulty = Mountain.ClimbingDifficulty(rawValue: 100)!

  MountainCardView(mountain: mountain)
    .padding()
}
