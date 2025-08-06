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
    .clipShape(RoundedRectangle(cornerRadius: 20))
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

      Text(self.mountain.locationName.localizedStringResource)
        .font(.caption)
        .foregroundStyle(.secondary)
      
      DifficultyView(difficulty: self.mountain.difficulty)
        .padding(.top, 5)
      
      Spacer()
      
      HStack(alignment: .center) {
        Image(systemName: "mountain.2.fill")
        Text(
          self.mountain.elevation.converted(to: .feet)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
        )
      }
      .font(.footnote)
    }
    .frame(maxWidth: .infinity, alignment: .leading)

    let image = ImageDataView(url: self.mountain.imageURL) { status in
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

// MARK: - DifficultyView

private struct DifficultyView: View {
  let difficulty: Mountain.ClimbingDifficulty
  
  var body: some View {
    Group {
      let formattedDifficulty = self.difficulty.rawValue.formatted(.number)
      let formattedRating = self.difficulty.rating.localizedStringResource
      Text("\(formattedRating): \(formattedDifficulty)")
    }
    .font(.footnote.bold())
    .foregroundStyle(.white)
    .padding(10)
    .background(Color(rating: self.difficulty.rating).gradient)
    .clipShape(Capsule())
  }
}

#Preview {
  var mountain = Mountain.mock2
  let _ = mountain.difficulty = Mountain.ClimbingDifficulty(rawValue: 100)!
  
  MountainCardView(mountain: mountain)
    .padding()
}
