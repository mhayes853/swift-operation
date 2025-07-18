import Dependencies
import Tagged
import UUIDV7

// MARK: - ApplicationLaunchID

public enum _ApplicationLaunchIDTag {}
public typealias ApplicationLaunchID = Tagged<_ApplicationLaunchIDTag, UUIDV7>

// MARK: - ApplicationLaunchIDKey

public enum ApplicationLaunchIDKey: DependencyKey {
  public static let liveValue = ApplicationLaunchID()
  public static var testValue: ApplicationLaunchID {
    ApplicationLaunchID()
  }
}
