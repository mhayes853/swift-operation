import Dependencies
import Tagged
import UUIDV7

// MARK: - ApplicationLaunch

public typealias ApplicationLaunch = ApplicationLaunchRecord

// MARK: - ApplicationLaunch.ID

extension ApplicationLaunch {
  public typealias ID = Tagged<Self, UUIDV7>
}

extension ApplicationLaunch.ID: @retroactive DependencyKey {
  public static let liveValue = ApplicationLaunch.ID()
  public static var testValue: ApplicationLaunch.ID {
    ApplicationLaunch.ID()
  }
}

extension ApplicationLaunch.ID: @retroactive TestDependencyKey {}
