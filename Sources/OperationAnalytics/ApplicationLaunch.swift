import UUIDV7

public struct ApplicationLaunch: Identifiable, Sendable {
  public let id: UUIDV7
  public let deviceName: DeviceName
}
